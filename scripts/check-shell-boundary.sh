#!/usr/bin/env bash
#
# Scans a native Ouro app checkout for app-local implementations of surfaces
# owned by ouro-native-apple-app-shell. Consumers keep a small allowlist for
# legacy or intentionally app-specific glue; new matches fail CI by default.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="."
ALLOWLIST=""

usage() {
  cat >&2 <<'USAGE'
Usage: check-shell-boundary.sh [--repo PATH] [--allowlist FILE] [--selftest]

Rules are intentionally textual and conservative: they catch new app-local
shell-owned primitives before review memory has to. Add an allowlist entry only
when the code is app-domain behavior or intentionally adapter glue.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      [ "$#" -ge 2 ] || fail "--repo requires a path"
      REPO="$2"
      shift 2
      ;;
    --allowlist)
      [ "$#" -ge 2 ] || fail "--allowlist requires a path"
      ALLOWLIST="$2"
      shift 2
      ;;
    --selftest)
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      mkdir -p "$tmp/Sources/App" "$tmp/Sources/AppShellAdapter" "$tmp/scripts"
      cat >"$tmp/Sources/App/AppDelegate.swift" <<'EOF'
import AppKit
func bad() { _ = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false) }
EOF
      cat >"$tmp/Sources/AppShellAdapter/Adapter.swift" <<'EOF'
import AppKit
func allowed() { _ = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false) }
EOF
      cat >"$tmp/Sources/App/OuroMDShellContract.swift" <<'EOF'
import OuroAppShellContract
func contract() -> OuroAppShellContract? { nil }
EOF
      cat >"$tmp/Sources/App/LeakyShellContract.swift" <<'EOF'
import SwiftUI
func badContract() -> some View { AppShellCommandReferenceView(catalog: AppShellCommandReferenceCatalog(title: "Commands", sections: [])) }
EOF
      cat >"$tmp/Sources/App/OuroMDAppShellContract.swift" <<'EOF'
import SwiftUI
func alsoBadContract() -> some View { AppShellCommandReferenceView(catalog: AppShellCommandReferenceCatalog(title: "Commands", sections: [])) }
EOF
      if "$ROOT/scripts/check-shell-boundary.sh" --repo "$tmp" >/tmp/ouro-shell-boundary-selftest.out 2>/tmp/ouro-shell-boundary-selftest.err; then
        cat /tmp/ouro-shell-boundary-selftest.out >&2
        fail "selftest expected app-local NSWindow violation"
      fi
      grep -Fq "Sources/App/AppDelegate.swift" /tmp/ouro-shell-boundary-selftest.err || fail "selftest did not report app-local violation"
      grep -Fq "OuroMDShellContract.swift" /tmp/ouro-shell-boundary-selftest.err && fail "selftest should allow shell contract files"
      grep -Fq "Sources/App/LeakyShellContract.swift" /tmp/ouro-shell-boundary-selftest.err || fail "selftest should still report shell UI inside contract files"
      grep -Fq "Sources/App/OuroMDAppShellContract.swift" /tmp/ouro-shell-boundary-selftest.err || fail "selftest should report shell UI inside AppShellContract files"
      cat >"$tmp/scripts/shell-boundary-allowlist.txt" <<'EOF'
Sources/App/AppDelegate.swift	NSWindow(contentRect	legacy fixture
Sources/App/LeakyShellContract.swift	AppShellCommandReferenceView(	leaky fixture
Sources/App/OuroMDAppShellContract.swift	AppShellCommandReferenceView(	leaky AppShellContract fixture
EOF
      "$ROOT/scripts/check-shell-boundary.sh" --repo "$tmp" --allowlist "$tmp/scripts/shell-boundary-allowlist.txt" >/dev/null
      printf 'Shell boundary scanner selftest ok\n'
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

[ -d "$REPO" ] || fail "repo path does not exist: $REPO"
REPO="$(cd "$REPO" && pwd)"
if [ -z "$ALLOWLIST" ]; then
  ALLOWLIST="$REPO/scripts/shell-boundary-allowlist.txt"
fi

allowlist_rows=""
if [ -f "$ALLOWLIST" ]; then
  while IFS=$'\t' read -r path pattern reason || [ -n "${path:-}" ]; do
    case "${path:-}" in
      ""|\#*) continue ;;
    esac
    [ -n "${pattern:-}" ] || fail "allowlist row missing pattern: $path"
    [ -n "${reason:-}" ] || fail "allowlist row missing reason: $path $pattern"
    allowlist_rows="${allowlist_rows}${path}"$'\t'"${pattern}"$'\n'
  done < "$ALLOWLIST"
fi

rules=(
  "NSWindow(contentRect"
  "NSAlert()"
  "AppShellAboutView("
  "ReleaseUpdateControls("
  "UpdateInstalledConfirmationView("
  "AppShellCommandReferenceView("
)

is_adapter_path() {
  case "$1" in
    *ShellAdapter*|*AppInfoView.swift|*ShellPresentation*) return 0 ;;
    *) return 1 ;;
  esac
}

is_allowed() {
  local rel="$1"
  local pattern="$2"
  [ -n "$allowlist_rows" ] || return 1
  printf '%s' "$allowlist_rows" | grep -Fqx "$rel"$'\t'"$pattern"
}

violations=()
for pattern in "${rules[@]}"; do
  while IFS= read -r match; do
    [ -n "$match" ] || continue
    path="${match%%:*}"
    rel="${path#$REPO/}"
    if is_adapter_path "$rel"; then
      continue
    fi
    if is_allowed "$rel" "$pattern"; then
      continue
    fi
    violations+=("$rel"$'\t'"$pattern")
  done < <(grep -R -n -F -- "$pattern" "$REPO/Sources" 2>/dev/null || true)
done

if [ "${#violations[@]}" -gt 0 ]; then
  {
    printf 'Shell boundary violations found in %s:\n' "$REPO"
    printf '\n'
    for entry in "${violations[@]}"; do
      IFS=$'\t' read -r path pattern <<EOF
$entry
EOF
      printf '  %s\t%s\n' "$path" "$pattern"
    done
    printf '\nMove shared native app-shell behavior into ouro-native-apple-app-shell, or add a documented allowlist row when this is intentionally app-domain/adapter glue.\n'
  } >&2
  exit 1
fi

printf 'Shell boundary scan ok: %s\n' "$REPO"
