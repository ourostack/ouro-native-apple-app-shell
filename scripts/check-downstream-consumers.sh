#!/usr/bin/env bash
#
# Verifies that the current shell checkout still works when used as a local
# SwiftPM override by downstream native apps.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_ROOT="${OURO_DOWNSTREAM_WORK_ROOT:-"$ROOT/.downstream-consumers"}"
CONTRACT_FILE="${OURO_DOWNSTREAM_CONSUMER_CONTRACT:-"$ROOT/scripts/downstream-consumers.contract.tsv"}"
REF_MODE="${OURO_DOWNSTREAM_CONSUMER_REF_MODE:-pinned}"
SHELL_PACKAGE="ouro-native-apple-app-shell"
SHELL_PACKAGE_URL="https://github.com/ourostack/ouro-native-apple-app-shell.git"
STRICT_FLAGS=(-Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete)
CONTRACT_ENTRIES=()

usage() {
  cat >&2 <<'USAGE'
Usage: check-downstream-consumers.sh [--consumer ouro-md] [--consumer ouro-workbench] [--ref-mode pinned|live]

By default, checks all downstream consumers in disposable clones under:
  .downstream-consumers

Override with OURO_DOWNSTREAM_WORK_ROOT=/tmp/some-dir when desired.
By default, consumer refs come from scripts/downstream-consumers.contract.tsv.
Use --ref-mode live, or OURO_DOWNSTREAM_CONSUMER_REF_MODE=live, for live-main canaries.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

load_contract() {
  [ -f "$CONTRACT_FILE" ] || fail "missing downstream consumer contract: $CONTRACT_FILE"

  local line name repo pinned_ref live_ref
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ""|\#*) continue ;;
    esac

    IFS=$'\t' read -r name repo pinned_ref live_ref <<EOF
$line
EOF

    [ -n "$name" ] || fail "contract entry has empty name: $line"
    [ -n "$repo" ] || fail "contract entry for $name has empty repository"
    [ -n "$pinned_ref" ] || fail "contract entry for $name has empty pinned_ref"
    [ -n "$live_ref" ] || fail "contract entry for $name has empty live_ref"
    CONTRACT_ENTRIES+=("$name"$'\t'"$repo"$'\t'"$pinned_ref"$'\t'"$live_ref")
  done < "$CONTRACT_FILE"

  [ "${#CONTRACT_ENTRIES[@]}" -gt 0 ] || fail "downstream consumer contract is empty: $CONTRACT_FILE"
}

contract_entry_for() {
  local requested="$1"
  local entry name repo pinned_ref live_ref
  for entry in "${CONTRACT_ENTRIES[@]}"; do
    IFS=$'\t' read -r name repo pinned_ref live_ref <<EOF
$entry
EOF
    if [ "$name" = "$requested" ]; then
      printf '%s\n' "$entry"
      return 0
    fi
  done
  return 1
}

contract_names() {
  local entry name repo pinned_ref live_ref
  for entry in "${CONTRACT_ENTRIES[@]}"; do
    IFS=$'\t' read -r name repo pinned_ref live_ref <<EOF
$entry
EOF
    printf '%s\n' "$name"
  done
}

validate_ref_mode() {
  case "$REF_MODE" in
    pinned|live) ;;
    *) fail "unknown ref mode: $REF_MODE" ;;
  esac
}

consumers=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --consumer)
      [ "$#" -ge 2 ] || fail "--consumer requires a value"
      consumers+=("$2")
      shift 2
      ;;
    --ref-mode)
      [ "$#" -ge 2 ] || fail "--ref-mode requires a value"
      REF_MODE="$2"
      shift 2
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

load_contract
validate_ref_mode

if [ "${#consumers[@]}" -eq 0 ]; then
  while IFS= read -r consumer_name; do
    consumers+=("$consumer_name")
  done < <(contract_names)
else
  for consumer in "${consumers[@]}"; do
    contract_entry_for "$consumer" >/dev/null || fail "unknown consumer: $consumer"
  done
fi

mkdir -p "$WORK_ROOT"

run() {
  printf '\n==> %s\n' "$*" >&2
  "$@"
}

prepare_consumer() {
  local name="$1"
  local entry url pinned_ref live_ref ref actual_ref
  local dir="$WORK_ROOT/$name"
  entry="$(contract_entry_for "$name")" || fail "unknown consumer: $name"
  IFS=$'\t' read -r name url pinned_ref live_ref <<EOF
$entry
EOF

  case "$REF_MODE" in
    pinned) ref="$pinned_ref" ;;
    live) ref="$live_ref" ;;
  esac

  printf '\nConsumer contract: %s\n  repository: %s\n  mode: %s\n  ref: %s\n' "$name" "$url" "$REF_MODE" "$ref" >&2

  if [ -d "$dir/.git" ]; then
    run git -C "$dir" remote set-url origin "$url"
  else
    rm -rf "$dir"
    mkdir -p "$dir"
    run git -C "$dir" init
    run git -C "$dir" remote add origin "$url"
  fi

  run git -C "$dir" fetch --depth 1 origin "$ref"
  run git -C "$dir" checkout --detach FETCH_HEAD
  run git -C "$dir" reset --hard FETCH_HEAD
  run git -C "$dir" clean -fdx

  actual_ref="$(git -C "$dir" rev-parse HEAD)"
  printf '  resolved: %s\n' "$actual_ref" >&2
  if [ "$REF_MODE" = "pinned" ] && [ "$actual_ref" != "$pinned_ref" ]; then
    fail "$name resolved $actual_ref, expected pinned ref $pinned_ref"
  fi
}

override_shell_package() {
  local dir="$1"
  local manifest="$dir/Package.swift"

  [ -f "$manifest" ] || fail "$dir is missing Package.swift"
  grep -Fq "$SHELL_PACKAGE_URL" "$manifest" || fail "$manifest does not depend on $SHELL_PACKAGE_URL"

  OURO_SHELL_OVERRIDE_PATH="$ROOT" perl -0pi -e '
    my $path = $ENV{"OURO_SHELL_OVERRIDE_PATH"};
    $path =~ s/\\/\\\\/g;
    $path =~ s/"/\\"/g;
    my $count = s{
      \.package\(
        \s*url:\s*"https://github\.com/ourostack/ouro-native-apple-app-shell\.git",
        \s*branch:\s*"main"
      \)
    }{.package(name: "ouro-native-apple-app-shell", path: "$path")}gx;
    die "did not replace ouro-native-apple-app-shell dependency\n" unless $count == 1;
  ' "$manifest"

  grep -Fq ".package(name: \"$SHELL_PACKAGE\", path: \"$ROOT\")" "$manifest" || fail "$manifest was not overridden to $ROOT"

  run swift package --package-path "$dir" resolve

  local root_real
  root_real="$(cd "$ROOT" && pwd -P)"
  swift package --package-path "$dir" show-dependencies | grep -Fq "$root_real" || fail "$dir did not resolve $SHELL_PACKAGE to $root_real"
}

check_ouro_md() {
  local dir="$WORK_ROOT/ouro-md"
  prepare_consumer ouro-md
  override_shell_package "$dir"

  run swift build --package-path "$dir"
  run swift test --package-path "$dir"
  run "$dir/.build/debug/ouro-md" --uisurfacetest
}

check_ouro_workbench() {
  local dir="$WORK_ROOT/ouro-workbench"
  prepare_consumer ouro-workbench
  override_shell_package "$dir"

  run swift test --package-path "$dir" "${STRICT_FLAGS[@]}"
  run swift run --package-path "$dir" "${STRICT_FLAGS[@]}" OuroWorkbench --uisurfacetest
}

for consumer in "${consumers[@]}"; do
  case "$consumer" in
    ouro-md) check_ouro_md ;;
    ouro-workbench) check_ouro_workbench ;;
  esac
done

printf '\nDownstream consumer compatibility ok (%s refs): %s\n' "$REF_MODE" "${consumers[*]}"
