#!/usr/bin/env bash
#
# Verifies that the current shell checkout still works when used as a local
# SwiftPM override by downstream native apps.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_ROOT="${OURO_DOWNSTREAM_WORK_ROOT:-"$ROOT/.downstream-consumers"}"
SHELL_PACKAGE="ouro-native-apple-app-shell"
SHELL_PACKAGE_URL="https://github.com/ourostack/ouro-native-apple-app-shell.git"
STRICT_FLAGS=(-Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete)

usage() {
  cat >&2 <<'USAGE'
Usage: check-downstream-consumers.sh [--consumer ouro-md] [--consumer ouro-workbench]

By default, checks all downstream consumers in disposable clones under:
  .downstream-consumers

Override with OURO_DOWNSTREAM_WORK_ROOT=/tmp/some-dir when desired.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

consumers=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --consumer)
      [ "$#" -ge 2 ] || fail "--consumer requires a value"
      case "$2" in
        ouro-md|ouro-workbench) consumers+=("$2") ;;
        *) fail "unknown consumer: $2" ;;
      esac
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

if [ "${#consumers[@]}" -eq 0 ]; then
  consumers=(ouro-md ouro-workbench)
fi

mkdir -p "$WORK_ROOT"

run() {
  printf '\n==> %s\n' "$*" >&2
  "$@"
}

prepare_consumer() {
  local name="$1"
  local url="https://github.com/ourostack/${name}.git"
  local dir="$WORK_ROOT/$name"

  if [ -d "$dir/.git" ]; then
    run git -C "$dir" fetch --depth 1 origin main
    run git -C "$dir" reset --hard FETCH_HEAD
    run git -C "$dir" clean -fdx
  else
    rm -rf "$dir"
    run git clone --depth 1 --branch main "$url" "$dir"
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

printf '\nDownstream consumer compatibility ok: %s\n' "${consumers[*]}"
