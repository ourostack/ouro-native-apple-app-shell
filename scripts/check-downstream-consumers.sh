#!/usr/bin/env bash
#
# Verifies that the current shell checkout still works when used as a local
# SwiftPM override by downstream native apps.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_ROOT="${OURO_DOWNSTREAM_WORK_ROOT:-"$ROOT/.downstream-consumers"}"
CONTRACT_FILE="${OURO_DOWNSTREAM_CONSUMER_CONTRACT:-"$ROOT/scripts/downstream-consumers.json"}"
REF_MODE="${OURO_DOWNSTREAM_CONSUMER_REF_MODE:-pinned}"
STEP_TIMEOUT_SECONDS="${OURO_DOWNSTREAM_STEP_TIMEOUT_SECONDS:-1200}"
RUN_LOG_DIR="${OURO_DOWNSTREAM_LOG_DIR:-"$WORK_ROOT/_logs"}"
RUN_ENV_ROOT="${OURO_DOWNSTREAM_ENV_ROOT:-"$WORK_ROOT/_env"}"
SHELL_PACKAGE="ouro-native-apple-app-shell"
SHELL_PACKAGE_URL="https://github.com/ourostack/ouro-native-apple-app-shell.git"
CONTRACT_ENTRIES=()
RUN_INDEX=0
CURRENT_CONSUMER="setup"
KEEP_WORKTREE="${OURO_DOWNSTREAM_KEEP_WORKTREE:-false}"

usage() {
  cat >&2 <<'USAGE'
Usage: check-downstream-consumers.sh [--consumer ouro-md] [--consumer ouro-workbench] [--ref-mode pinned|live] [--check-pins-current|--warn-pins-current] [--print-matrix] [--keep-worktree] [--selftest]

By default, checks all downstream consumers in disposable clones under:
  .downstream-consumers

Override with OURO_DOWNSTREAM_WORK_ROOT=/tmp/some-dir when desired.
By default, consumer refs and smoke commands come from scripts/downstream-consumers.json.
Use --ref-mode live, or OURO_DOWNSTREAM_CONSUMER_REF_MODE=live, for live-main canaries.
Use --check-pins-current to fail fast when pinned_ref differs from live_ref.
Use --warn-pins-current to warn on stale pins while still failing contract/resolve errors.
Use --print-matrix to emit a GitHub Actions matrix JSON object from the manifest.
Completed consumer clones are removed by default. Use --keep-worktree to retain them for debugging.
Set OURO_DOWNSTREAM_STEP_TIMEOUT_SECONDS=0 to disable the per-command timeout.
Consumer Swift gates run with isolated HOME/CFFIXED_USER_HOME roots under the work root.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

load_contract() {
  [ -f "$CONTRACT_FILE" ] || fail "missing downstream consumer contract: $CONTRACT_FILE"

  local line
  while IFS= read -r line || [ -n "$line" ]; do
    CONTRACT_ENTRIES+=("$line")
  done < <(python3 - "$CONTRACT_FILE" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)

if data.get("schema_version") != 1:
    raise SystemExit(f"{path}: schema_version must be 1")
consumers = data.get("consumers")
if not isinstance(consumers, list) or not consumers:
    raise SystemExit(f"{path}: consumers must be a non-empty list")

seen = set()
for index, consumer in enumerate(consumers):
    if not isinstance(consumer, dict):
        raise SystemExit(f"{path}: consumers[{index}] must be an object")
    missing = [key for key in ("name", "repository", "pinned_ref", "live_ref", "smoke_commands") if not consumer.get(key)]
    if missing:
        raise SystemExit(f"{path}: consumers[{index}] missing {', '.join(missing)}")
    name = consumer["name"]
    if name in seen:
        raise SystemExit(f"{path}: duplicate consumer name {name}")
    seen.add(name)
    commands = consumer["smoke_commands"]
    if not isinstance(commands, list) or not all(isinstance(command, str) and "{dir}" in command for command in commands):
        raise SystemExit(f"{path}: {name} smoke_commands must be strings containing {dir}")
    print("\t".join([name, consumer["repository"], consumer["pinned_ref"], consumer["live_ref"]]))
PY
  )

  [ "${#CONTRACT_ENTRIES[@]}" -gt 0 ] || fail "downstream consumer contract is empty: $CONTRACT_FILE"
}

print_matrix() {
  python3 - "$CONTRACT_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
print(json.dumps({"consumer": [consumer["name"] for consumer in data["consumers"]]}, separators=(",", ":")))
PY
}

consumer_smoke_commands() {
  local requested="$1"
  python3 - "$CONTRACT_FILE" "$requested" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
for consumer in data["consumers"]:
    if consumer["name"] == sys.argv[2]:
        for command in consumer["smoke_commands"]:
            print(command)
        break
else:
    raise SystemExit(f"unknown consumer: {sys.argv[2]}")
PY
}

expand_consumer_command() {
  local dir="$1"
  local template="$2"
  python3 - "$dir" "$template" <<'PY'
import shlex
import sys

print(sys.argv[2].replace("{dir}", shlex.quote(sys.argv[1])))
PY
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

resolve_live_ref() {
  local repo="$1"
  local live_ref="$2"
  local remote_ref="$live_ref"
  local resolved

  if [[ "$live_ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf '%s\n' "$live_ref"
    return 0
  fi

  case "$remote_ref" in
    refs/*) ;;
    *) remote_ref="refs/heads/$remote_ref" ;;
  esac

  resolved="$(git ls-remote "$repo" "$remote_ref" | awk 'NR == 1 {print $1}')"
  [ -n "$resolved" ] || fail "could not resolve $repo $remote_ref"
  printf '%s\n' "$resolved"
}

check_pins_current() {
  local consumer entry name repo pinned_ref live_ref live_resolved
  local failures=0

  for consumer in "${consumers[@]}"; do
    entry="$(contract_entry_for "$consumer")" || fail "unknown consumer: $consumer"
    IFS=$'\t' read -r name repo pinned_ref live_ref <<EOF
$entry
EOF
    live_resolved="$(resolve_live_ref "$repo" "$live_ref")"
    if [ "$pinned_ref" != "$live_resolved" ]; then
      printf 'stale pin: %s\n  pinned_ref: %s\n  %s: %s\n' "$name" "$pinned_ref" "$live_ref" "$live_resolved" >&2
      failures=$((failures + 1))
    else
      printf 'current pin: %s %s\n' "$name" "$pinned_ref" >&2
    fi
  done

  if [ "$failures" -eq 0 ]; then
    return 0
  fi

  if [ "$WARN_PINS_CURRENT" = true ]; then
    printf '::warning title=Downstream pins moved::Refresh scripts/downstream-consumers.contract.tsv when adopting a new consumer baseline. Pinned downstream smokes remain the blocking compatibility gate; live-main canaries cover latest consumer refs.\n' >&2
    return 0
  fi

  fail "$failures downstream consumer pin(s) are stale"
}

consumers=()
CHECK_PINS_CURRENT=false
WARN_PINS_CURRENT=false
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
    --check-pins-current)
      CHECK_PINS_CURRENT=true
      shift
      ;;
    --warn-pins-current)
      WARN_PINS_CURRENT=true
      shift
      ;;
    --print-matrix)
      PRINT_MATRIX=true
      shift
      ;;
    --keep-worktree)
      KEEP_WORKTREE=true
      shift
      ;;
    --selftest)
      SELFTEST=true
      shift
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

if [ "${PRINT_MATRIX:-false}" = true ]; then
  print_matrix
  exit 0
fi

if [ "${SELFTEST:-false}" = true ]; then
  matrix="$(print_matrix)"
  [ "$matrix" = '{"consumer":["ouro-md","ouro-workbench"]}' ] || fail "unexpected manifest matrix: $matrix"
  consumer_smoke_commands ouro-md | grep -Fq 'swift test --package-path {dir}' || fail "ouro-md smoke commands missing swift test"
  consumer_smoke_commands ouro-workbench | grep -Fq 'OuroWorkbench --uisurfacetest' || fail "ouro-workbench smoke commands missing UI surface test"
  if consumer_smoke_commands missing-consumer >/tmp/ouro-downstream-missing.out 2>/tmp/ouro-downstream-missing.err; then
    fail "selftest expected unknown consumer lookup to fail"
  fi
  grep -Fq "unknown consumer: missing-consumer" /tmp/ouro-downstream-missing.err || fail "selftest did not report unknown consumer"
  expanded="$(expand_consumer_command "/tmp/path with spaces/app" "{dir}/.build/debug/ouro-md --uisurfacetest")"
  [ "$expanded" = "'/tmp/path with spaces/app'/.build/debug/ouro-md --uisurfacetest" ] || fail "unexpected command expansion: $expanded"
  printf 'Downstream consumer manifest selftest ok\n'
  exit 0
fi

if [ "${#consumers[@]}" -eq 0 ]; then
  while IFS= read -r consumer_name; do
    consumers+=("$consumer_name")
  done < <(contract_names)
else
  for consumer in "${consumers[@]}"; do
    contract_entry_for "$consumer" >/dev/null || fail "unknown consumer: $consumer"
  done
fi

if [ "$CHECK_PINS_CURRENT" = true ] && [ "$WARN_PINS_CURRENT" = true ]; then
  fail "--check-pins-current and --warn-pins-current are mutually exclusive"
fi

if [ "$CHECK_PINS_CURRENT" = true ] || [ "$WARN_PINS_CURRENT" = true ]; then
  check_pins_current
  exit 0
fi

mkdir -p "$WORK_ROOT" "$RUN_LOG_DIR" "$RUN_ENV_ROOT"

run() {
  RUN_INDEX=$((RUN_INDEX + 1))
  local slug log
  slug="$(printf '%s' "$CURRENT_CONSUMER-$RUN_INDEX-$*" | tr -cs '[:alnum:]_.=-' '-' | cut -c 1-120)"
  log="$RUN_LOG_DIR/$slug.log"

  printf '\n==> %s\n    log: %s\n' "$*" "$log" >&2
  python3 - "$STEP_TIMEOUT_SECONDS" "$log" "$@" <<'PY'
import os
import selectors
import signal
import subprocess
import sys
import time

timeout = int(sys.argv[1])
log_path = sys.argv[2]
cmd = sys.argv[3:]
deadline = time.monotonic() + timeout if timeout > 0 else None

with open(log_path, "wb") as log:
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    assert process.stdout is not None
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)

    def emit(chunk: bytes) -> None:
        if not chunk:
            return
        log.write(chunk)
        log.flush()
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()

    while True:
        for key, _ in selector.select(timeout=0.2):
            emit(os.read(key.fileobj.fileno(), 65536))

        status = process.poll()
        if status is not None:
            emit(process.stdout.read())
            sys.exit(status)

        if deadline is not None and time.monotonic() >= deadline:
            message = (
                f"\nerror: command timed out after {timeout}s: "
                + " ".join(cmd)
                + "\n"
            ).encode()
            emit(message)
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()
            sys.exit(124)
PY
}

run_consumer() {
  local home tmp
  home="$RUN_ENV_ROOT/$CURRENT_CONSUMER-home"
  tmp="$RUN_ENV_ROOT/$CURRENT_CONSUMER-tmp"
  mkdir -p "$home/Library/Preferences" "$home/Library/Application Support" "$tmp"
  run env \
    HOME="$home" \
    CFFIXED_USER_HOME="$home" \
    TMPDIR="$tmp/" \
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
    run git -C "$dir" reset --hard
    run git -C "$dir" clean -fdx
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

  mkdir -p "$dir/.build/checkouts"
  rm -rf "$dir/.build/checkouts/$SHELL_PACKAGE"
  ln -s "$ROOT" "$dir/.build/checkouts/$SHELL_PACKAGE"

  local root_real
  root_real="$(cd "$ROOT" && pwd -P)"
  if ! run bash -c 'swift package --package-path "$1" show-dependencies | grep -Fq "$2"' _ "$dir" "$root_real"; then
    fail "$dir did not resolve $SHELL_PACKAGE to $root_real"
  fi
}

check_shell_adoption() {
  local name="$1"
  local dir="$2"

  run "$ROOT/scripts/shell-doctor.sh" --repo "$dir" --consumer "$name"
}

check_manifest_consumer() {
  local name="$1"
  local dir="$WORK_ROOT/$name"
  local command expanded
  CURRENT_CONSUMER="$name"
  prepare_consumer "$name"
  override_shell_package "$dir"
  check_shell_adoption "$name" "$dir"

  while IFS= read -r command || [ -n "$command" ]; do
    expanded="$(expand_consumer_command "$dir" "$command")"
    run_consumer bash -lc "$expanded"
  done < <(consumer_smoke_commands "$name")

  if [ "$KEEP_WORKTREE" != true ]; then
    rm -rf "$dir"
  fi
}

for consumer in "${consumers[@]}"; do
  check_manifest_consumer "$consumer"
done

printf '\nDownstream consumer compatibility ok (%s refs): %s\n' "$REF_MODE" "${consumers[*]}"
