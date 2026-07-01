#!/usr/bin/env bash
#
# Checks that a downstream native Ouro app has adopted the shared app shell in
# the executable, CI-enforced shape expected by this package.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO=""
CONSUMER=""
ALLOWLIST=""
SELFTEST_TMP=""

usage() {
  cat >&2 <<'USAGE'
Usage: shell-doctor.sh --repo PATH [--consumer NAME] [--allowlist FILE] [--selftest]

Checks a consumer repository for the shared Ouro native app-shell adoption path:
SwiftPM dependency/products, typed shell contract source, consumer contract
tests, shell dependency/boundary scripts in preflight, and the shell boundary
scanner itself.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

run_static_checks() {
  local repo="$1"
  local consumer="$2"

  python3 - "$repo" "$consumer" <<'PY'
import json
import os
import pathlib
import re
import shlex
import stat
import sys

repo = pathlib.Path(sys.argv[1]).resolve()
consumer = sys.argv[2] or repo.name
shell_url = "https://github.com/ourostack/ouro-native-apple-app-shell.git"
assignment_pattern = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
issues = []
checks = []
notes = []

def rel(path):
    try:
        return path.relative_to(repo).as_posix()
    except ValueError:
        return str(path)

def add_check(message):
    checks.append(message)

def add_issue(message):
    issues.append(message)

def read(path):
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        add_issue(f"missing {rel(path)}")
        return ""

def swift_files(directory):
    root = repo / directory
    if not root.exists():
        add_issue(f"missing {directory}/")
        return []
    return sorted(path for path in root.rglob("*.swift") if path.is_file())

def script_files():
    root = repo / "scripts"
    if not root.exists():
        add_issue("missing scripts/")
        return []
    return sorted(path for path in root.rglob("*.sh") if path.is_file())

def shell_tokens(line):
    lexer = shlex.shlex(line, posix=True, punctuation_chars=";&|<")
    lexer.whitespace_split = True
    lexer.commenters = "#"
    return list(lexer)

def is_function_definition(line, tokens):
    stripped = line.strip()
    if re.match(r"(function\s+)?[A-Za-z_][A-Za-z0-9_]*\s*(\(\))?\s*\{", stripped):
        return True
    return len(tokens) >= 2 and tokens[0].endswith("()") and tokens[1] == "{"

def top_level_block_delta(line, tokens):
    if not tokens:
        return 0
    openers = 0
    closers = sum(1 for token in tokens if token in {"fi", "done", "esac", "}"})
    if tokens[0] in {"if", "while", "until", "for", "case", "select"}:
        openers += 1
    if is_function_definition(line, tokens):
        openers += 1
    if "{" in tokens and not is_function_definition(line, tokens):
        openers += 1
    return openers - closers

def shell_command_index(words):
    command_index = 0
    while command_index < len(words) and assignment_pattern.match(words[command_index]):
        command_index += 1
    return command_index

def effective_command_index(words):
    command_index = shell_command_index(words)
    if command_index < len(words) and words[command_index] in {"command", "builtin"}:
        command_index += 1
    return command_index

def effective_command(words):
    command_index = effective_command_index(words)
    if command_index < len(words):
        return words[command_index]
    return ""

def set_enables_errexit(words):
    command_index = shell_command_index(words)
    if command_index >= len(words) or words[command_index] != "set":
        return False
    args = words[command_index + 1:]
    for index, arg in enumerate(args):
        if arg.startswith("-") and "e" in arg:
            return True
        if arg == "-o" and index + 1 < len(args) and args[index + 1] == "errexit":
            return True
    return False

def set_disables_errexit(words):
    command_index = shell_command_index(words)
    if command_index >= len(words) or words[command_index] != "set":
        return False
    args = words[command_index + 1:]
    for index, arg in enumerate(args):
        if arg.startswith("+") and "e" in arg:
            return True
        if arg == "+o" and index + 1 < len(args) and args[index + 1] == "errexit":
            return True
    return False

def command_disables_fail_fast(words):
    command = effective_command(words)
    if command == "trap":
        return True
    return set_disables_errexit(words)

def first_simple_command(tokens):
    words = []
    for token in tokens:
        if set(token) <= {";", "&", "|"}:
            break
        words.append(token)
    return words

def heredoc_delimiters(tokens):
    delimiters = []
    for index, token in enumerate(tokens):
        if token in {"<<", "<<-"} and index + 1 < len(tokens):
            delimiter = tokens[index + 1]
            delimiter = delimiter.strip("\"'")
            if delimiter:
                delimiters.append(delimiter)
    return delimiters

def active_shell_commands(paths):
    commands = []
    for path in paths:
        blocked_depth = 0
        fail_fast_enabled = False
        fail_fast_poisoned = False
        terminal_reached = False
        heredoc_stack = []
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if heredoc_stack:
                if line.strip() == heredoc_stack[0]:
                    heredoc_stack.pop(0)
                continue
            if terminal_reached:
                break
            try:
                tokens = shell_tokens(line)
            except ValueError:
                continue
            pending_heredocs = heredoc_delimiters(tokens)
            if blocked_depth > 0:
                heredoc_stack.extend(pending_heredocs)
                blocked_depth = max(0, blocked_depth + top_level_block_delta(line, tokens))
                continue
            block_delta = top_level_block_delta(line, tokens)
            if block_delta > 0:
                blocked_depth = block_delta
                continue
            if tokens and tokens[0] in {"then", "else", "elif", "do"}:
                continue
            words = first_simple_command(tokens)
            command = effective_command(words)
            if command in {"exit", "return"}:
                terminal_reached = True
                continue
            if command == "exec":
                if not any(set(token) <= {";", "&", "|"} for token in tokens) and fail_fast_enabled:
                    commands.append(words)
                terminal_reached = True
                continue
            if any(set(token) <= {";", "&", "|"} for token in tokens):
                heredoc_stack.extend(pending_heredocs)
                continue
            if not words:
                heredoc_stack.extend(pending_heredocs)
                continue
            if set_enables_errexit(words):
                fail_fast_enabled = not fail_fast_poisoned
                commands.append(words)
                heredoc_stack.extend(pending_heredocs)
                continue
            if command_disables_fail_fast(words):
                if command == "trap":
                    fail_fast_poisoned = True
                fail_fast_enabled = False
                commands.append(words)
                heredoc_stack.extend(pending_heredocs)
                continue
            if fail_fast_enabled:
                commands.append(words)
            heredoc_stack.extend(pending_heredocs)
    return commands

def preflight_contract(path):
    state = {
        "fail_fast": False,
        "dependency": False,
        "boundary_selftest": False,
        "boundary_scan": False,
    }
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    index = 0

    def skip_blank_or_comment(current):
        while current < len(lines):
            stripped = lines[current].strip()
            if stripped == "" or stripped.startswith("#"):
                current += 1
                continue
            break
        return current

    def exact_line(current):
        if current >= len(lines):
            return ""
        line = lines[current]
        if line != line.strip() or line != line.rstrip():
            return ""
        return line

    def is_safe_root_preamble(line):
        if re.match(r"[A-Z_][A-Z0-9_]*=.*", line):
            return True
        return re.match(r'cd "\$[A-Z_][A-Z0-9_]*"', line) is not None

    if lines and lines[0].startswith("#!"):
        index = 1
    index = skip_blank_or_comment(index)
    if exact_line(index) != "set -euo pipefail":
        return state
    state["fail_fast"] = True
    index += 1

    expected = [
        ({"scripts/check-shell-dependency.sh", "./scripts/check-shell-dependency.sh"}, "dependency"),
        ({"scripts/check-shell-boundary.sh --selftest", "./scripts/check-shell-boundary.sh --selftest"}, "boundary_selftest"),
        ({"scripts/check-shell-boundary.sh", "./scripts/check-shell-boundary.sh"}, "boundary_scan"),
    ]
    expected_index = 0
    while expected_index < len(expected):
        index = skip_blank_or_comment(index)
        line = exact_line(index)
        if expected_index == 0 and is_safe_root_preamble(line):
            index += 1
            continue
        accepted_lines, key = expected[expected_index]
        if line not in accepted_lines:
            return state
        state[key] = True
        expected_index += 1
        index += 1
    return state

def has_shell_command(commands, script_name, *required_args):
    names = {script_name, f"./{script_name}", f"scripts/{script_name}", f"./scripts/{script_name}"}
    for words in commands:
        command_index = shell_command_index(words)
        if command_index >= len(words):
            continue
        command = words[command_index]
        if command not in names:
            continue
        args = words[command_index + 1:]
        if all(arg in args for arg in required_args):
            return True
    return False

def has_fail_fast(commands):
    for words in commands:
        if set_enables_errexit(words):
            return True
    return False

def shell_assignments(commands):
    assignments = {}
    for words in commands:
        for word in words:
            match = assignment_pattern.match(word)
            if not match:
                break
            assignments[match.group(1)] = match.group(2)
    return assignments

def resolve_shell_token(token, assignments):
    if token.startswith("${") and token.endswith("}"):
        return assignments.get(token[2:-1], token)
    if token.startswith("$") and len(token) > 1:
        return assignments.get(token[1:], token)
    return token

def boundary_checker_command_index(words):
    command_index = 0
    while command_index < len(words) and assignment_pattern.match(words[command_index]):
        command_index += 1
    if command_index < len(words) and words[command_index] in {"exec", "command"}:
        command_index += 1
    return command_index

def has_boundary_wrapper_delegate(path):
    commands = active_shell_commands([path])
    assignments = shell_assignments(commands)
    for words in commands:
        command_index = boundary_checker_command_index(words)
        if command_index >= len(words):
            continue
        command = resolve_shell_token(words[command_index], assignments)
        args = words[command_index + 1:]
        if "ouro-native-apple-app-shell/scripts/check-shell-boundary.sh" in command and "--repo" in args:
            return True
    return False

manifest_path = repo / "Package.swift"
manifest = read(manifest_path)
has_url_dependency = shell_url in manifest
has_path_dependency = (
    'package(name: "ouro-native-apple-app-shell", path:' in manifest
    or 'package(path:' in manifest and "ouro-native-apple-app-shell" in manifest
)
if has_url_dependency or has_path_dependency:
    add_check("Package.swift declares ouro-native-apple-app-shell dependency")
else:
    add_issue("Package.swift must depend on ouro-native-apple-app-shell by URL or local path override")

for product in ("OuroAppShellContract", "OuroAppShellConsumerTesting"):
    if f'.product(name: "{product}"' in manifest:
        add_check(f"Package.swift exposes {product} to a target")
    else:
        add_issue(f"Package.swift must reference product {product}")

if has_url_dependency:
    resolved_path = repo / "Package.resolved"
    resolved = read(resolved_path)
    if resolved:
        try:
            data = json.loads(resolved)
        except json.JSONDecodeError as exc:
            add_issue(f"Package.resolved must be valid JSON: {exc}")
        else:
            pin = next((pin for pin in data.get("pins", []) if pin.get("identity") == "ouro-native-apple-app-shell"), None)
            if not pin:
                add_issue("Package.resolved must pin ouro-native-apple-app-shell")
            else:
                state = pin.get("state", {})
                if pin.get("location") != shell_url:
                    add_issue("Package.resolved shell pin must use the canonical shell repository URL")
                elif state.get("branch") != "main":
                    add_issue("Package.resolved shell pin must track branch main")
                elif not state.get("revision"):
                    add_issue("Package.resolved shell pin must include a concrete revision")
                else:
                    add_check("Package.resolved pins the shell dependency on main")
else:
    notes.append("Package.resolved pin check skipped for local path override")

sources = swift_files("Sources")
source_texts = [(path, path.read_text(encoding="utf-8", errors="replace")) for path in sources]
contract_sources = [
    (path, text)
    for path, text in source_texts
    if "import OuroAppShellContract" in text and "OuroAppShellContract(" in text
]
if contract_sources:
    add_check("Sources declare a typed OuroAppShellContract")
else:
    add_issue("Sources must declare a typed OuroAppShellContract in the consumer shell adapter")

required_contract_tokens = [
    "requiredSurfaces",
    "OuroAppShellReleaseUpdateContract",
    "OuroAppShellAboutContract",
    "OuroAppShellCommandReferenceContract",
    "utilityWindows:",
    "OuroAppShellSettingsContract",
    "privacyDiagnostics:",
    "OuroAppShellPrivacyDiagnosticsContract",
]
contract_text = "\n".join(text for _, text in contract_sources)
for token in required_contract_tokens:
    if token in contract_text:
        add_check(f"contract source includes {token}")
    else:
        add_issue(f"consumer shell contract must include {token}")

tests = swift_files("Tests")
test_text = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in tests)
if "import OuroAppShellConsumerTesting" in test_text:
    add_check("Tests import OuroAppShellConsumerTesting")
else:
    add_issue("consumer tests must import OuroAppShellConsumerTesting")
if "OuroAppShellContractAssertions.assertValid" in test_text:
    add_check("Tests assert the shell contract is valid")
else:
    add_issue("consumer tests must call OuroAppShellContractAssertions.assertValid")
if "OuroAppShellContractAssertions.assertRequiresShellFirstSurfaces" in test_text:
    add_check("Tests assert the shell-first surface list")
else:
    add_issue("consumer tests must call OuroAppShellContractAssertions.assertRequiresShellFirstSurfaces")

control_deck_path = repo / "config" / "ouro-app-control-deck.json"
control_deck = read(control_deck_path)
if control_deck:
    try:
        control_data = json.loads(control_deck)
    except json.JSONDecodeError as exc:
        add_issue(f"config/ouro-app-control-deck.json must be valid JSON: {exc}")
    else:
        if control_data.get("schema_version") != 1:
            add_issue("config/ouro-app-control-deck.json must set schema_version to 1")
        else:
            add_check("control deck schema_version is 1")
        if control_data.get("local_manifest") != "config/ouro-app-control-deck.json":
            add_issue("control deck must declare local_manifest as config/ouro-app-control-deck.json")
        else:
            add_check("control deck declares its local manifest path")
        surfaces = control_data.get("adoption_surfaces")
        if not isinstance(surfaces, list) or not surfaces:
            add_issue("control deck must list adoption_surfaces")
        else:
            add_check("control deck lists adoption surfaces")

boundary_wrapper = repo / "scripts" / "check-shell-boundary.sh"
if boundary_wrapper.exists():
    mode = boundary_wrapper.stat().st_mode
    if mode & stat.S_IXUSR:
        add_check("scripts/check-shell-boundary.sh is executable")
    else:
        add_issue("scripts/check-shell-boundary.sh must be executable")
    if has_boundary_wrapper_delegate(boundary_wrapper):
        add_check("boundary wrapper delegates to the shell scanner with --repo")
    else:
        add_issue("scripts/check-shell-boundary.sh must delegate to the shell scanner with --repo")
    if has_fail_fast(active_shell_commands([boundary_wrapper])):
        add_check("scripts/check-shell-boundary.sh uses fail-fast shell mode")
    else:
        add_issue("scripts/check-shell-boundary.sh must enable fail-fast shell mode")
else:
    add_issue("missing scripts/check-shell-boundary.sh")

dependency_wrapper = repo / "scripts" / "check-shell-dependency.sh"
if dependency_wrapper.exists():
    mode = dependency_wrapper.stat().st_mode
    if mode & stat.S_IXUSR:
        add_check("scripts/check-shell-dependency.sh is executable")
    else:
        add_issue("scripts/check-shell-dependency.sh must be executable")
else:
    add_issue("missing scripts/check-shell-dependency.sh")

_ = script_files()
preflight_candidates = [
    repo / "scripts" / "pr-preflight.sh",
    repo / "scripts" / "preflight.sh",
]
preflight_paths = [path for path in preflight_candidates if path.exists()]
if not preflight_paths:
    add_issue("missing consumer preflight script: expected scripts/pr-preflight.sh or scripts/preflight.sh")
else:
    for path in preflight_paths:
        if path.stat().st_mode & stat.S_IXUSR:
            add_check(f"{rel(path)} is executable")
        else:
            add_issue(f"{rel(path)} must be executable")

    for path in preflight_paths:
        contract = preflight_contract(path)
        rel_path = rel(path)
        if contract["fail_fast"]:
            add_check(f"{rel(path)} uses fail-fast shell mode")
        else:
            add_issue(f"{rel(path)} must enable fail-fast shell mode")
        if contract["dependency"]:
            add_check(f"{rel_path} includes shell dependency freshness")
        else:
            add_issue(f"{rel_path} must run scripts/check-shell-dependency.sh")
        if contract["boundary_selftest"]:
            add_check(f"{rel_path} includes shell boundary selftest")
        else:
            add_issue(f"{rel_path} must run scripts/check-shell-boundary.sh --selftest")
        if contract["boundary_scan"]:
            add_check(f"{rel_path} includes shell boundary scan")
        else:
            add_issue(f"{rel_path} must run scripts/check-shell-boundary.sh")

if issues:
    print(f"Shell doctor found adoption issues in {consumer} ({repo}):", file=sys.stderr)
    for issue in issues:
        print(f"  - {issue}", file=sys.stderr)
    if checks:
        print("", file=sys.stderr)
        print("Checks already satisfied:", file=sys.stderr)
        for check in checks:
            print(f"  - {check}", file=sys.stderr)
    sys.exit(1)

print(f"Shell doctor static checks ok: {consumer} ({repo})")
for check in checks:
    print(f"  ok: {check}")
for note in notes:
    print(f"  note: {note}")
PY
}

run_boundary_scan() {
  local repo="$1"
  local allowlist="$2"

  if [ -z "$allowlist" ]; then
    allowlist="$repo/scripts/shell-boundary-allowlist.txt"
  fi

  if [ -f "$allowlist" ]; then
    "$ROOT/scripts/check-shell-boundary.sh" --repo "$repo" --allowlist "$allowlist"
  else
    "$ROOT/scripts/check-shell-boundary.sh" --repo "$repo"
  fi
}

run_boundary_wrapper_selftest() {
  local repo="$1"
  local output

  if ! output="$(cd "$repo" && OURO_APP_SHELL_ROOT="$ROOT" scripts/check-shell-boundary.sh --selftest 2>&1)"; then
    printf '%s\n' "$output" >&2
    return 1
  fi
  if ! grep -Fq "Shell boundary scanner selftest ok" <<<"$output"; then
    printf 'error: scripts/check-shell-boundary.sh --selftest must run the shell scanner selftest\n' >&2
    printf '%s\n' "$output" >&2
    return 1
  fi
  printf 'Shell boundary wrapper selftest ok: %s\n' "$repo"
}

run_boundary_wrapper_scan() {
  local repo="$1"
  local output

  if ! output="$(cd "$repo" && OURO_APP_SHELL_ROOT="$ROOT" scripts/check-shell-boundary.sh 2>&1)"; then
    printf '%s\n' "$output" >&2
    return 1
  fi
  if ! grep -Fq "Shell boundary scan ok" <<<"$output"; then
    printf 'error: scripts/check-shell-boundary.sh must run the shell boundary scan in normal mode\n' >&2
    printf '%s\n' "$output" >&2
    return 1
  fi
  printf 'Shell boundary wrapper scan ok: %s\n' "$repo"
}

run_doctor() {
  local repo="$1"
  local consumer="$2"
  local allowlist="$3"

  [ -d "$repo" ] || fail "repo path does not exist: $repo"
  repo="$(cd "$repo" && pwd)"
  [ -n "$consumer" ] || consumer="$(basename "$repo")"

  run_static_checks "$repo" "$consumer" || return 1
  run_boundary_wrapper_selftest "$repo" || return 1
  run_boundary_wrapper_scan "$repo" || return 1
  run_boundary_scan "$repo" "$allowlist" || return 1
  printf 'Shell doctor ok: %s (%s)\n' "$consumer" "$repo"
}

run_selftest() {
  local tmp valid invalid
  tmp="$(mktemp -d)"
  SELFTEST_TMP="$tmp"
  trap 'rm -rf "$SELFTEST_TMP"' EXIT
  valid="$tmp/valid-consumer"
  invalid="$tmp/invalid-consumer"

  mkdir -p "$valid/Sources/FakeApp" "$valid/Tests/FakeAppTests" "$valid/scripts"
  cat >"$valid/Package.swift" <<'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FakeConsumer",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/ourostack/ouro-native-apple-app-shell.git", branch: "main")
    ],
    targets: [
        .target(
            name: "FakeApp",
            dependencies: [
                .product(name: "OuroAppShellContract", package: "ouro-native-apple-app-shell")
            ]
        ),
        .testTarget(
            name: "FakeAppTests",
            dependencies: [
                "FakeApp",
                .product(name: "OuroAppShellConsumerTesting", package: "ouro-native-apple-app-shell")
            ]
        )
    ]
)
EOF
  cat >"$valid/Package.resolved" <<'EOF'
{
  "pins" : [
    {
      "identity" : "ouro-native-apple-app-shell",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/ourostack/ouro-native-apple-app-shell.git",
      "state" : {
        "branch" : "main",
        "revision" : "0123456789abcdef0123456789abcdef01234567"
      }
    }
  ],
  "version" : 3
}
EOF
  cat >"$valid/Sources/FakeApp/FakeShellContract.swift" <<'EOF'
import Foundation
import OuroAppShellContract

enum FakeShellContract {
    static let requiredSurfaces: [AppShellSurface] = [.appIdentity, .releaseUpdates, .about, .keyboardShortcuts, .settings, .windowChrome]
    static var contract: OuroAppShellContract {
        OuroAppShellContract(
            identity: AppShellIdentity(appName: "Fake", bundleIdentifier: "com.ouro.fake", repository: "ourostack/fake", version: "1.0.0"),
            requiredSurfaces: requiredSurfaces,
            releaseUpdates: OuroAppShellReleaseUpdateContract(policy: .stable(assetNamingPolicy: .versionedArchiveAndManifest(namePrefix: "Fake-")), supportsInstallAndRelaunch: true, supportsReleasePage: true),
            about: OuroAppShellAboutContract(subtitle: "Fake app", repositoryURL: URL(string: "https://github.com/ourostack/fake")),
            commandReference: OuroAppShellCommandReferenceContract(title: "Keyboard Shortcuts", commandCount: 1, sections: ["Global"], entryPoint: "Help > Keyboard Shortcuts"),
            commandManifest: OuroAppShellCommandSurfaceManifest(commands: [.init(id: "global.shortcuts", title: "Keyboard Shortcuts", section: "Global", shortcut: "⌘/")]),
            utilityWindows: [.init(id: "about", surface: .about, title: "About Fake")],
            settings: OuroAppShellSettingsContract(entryPoint: "Fake > Settings")
        )
    }
}
EOF
  cat >"$valid/Tests/FakeAppTests/FakeShellContractTests.swift" <<'EOF'
import XCTest
import OuroAppShellConsumerTesting
@testable import FakeApp

final class FakeShellContractTests: XCTestCase {
    func testContract() {
        OuroAppShellContractAssertions.assertValid(FakeShellContract.contract)
        OuroAppShellContractAssertions.assertRequiresShellFirstSurfaces(FakeShellContract.contract, FakeShellContract.requiredSurfaces)
    }
}
EOF
  mkdir -p "$valid/.build/checkouts/ouro-native-apple-app-shell/scripts"
  ln -s "$ROOT/scripts/check-shell-boundary.sh" "$valid/.build/checkouts/ouro-native-apple-app-shell/scripts/check-shell-boundary.sh"
  ln -s "$ROOT/scripts/analyze-shell-boundary.py" "$valid/.build/checkouts/ouro-native-apple-app-shell/scripts/analyze-shell-boundary.py"
  cat >"$valid/scripts/check-shell-boundary.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker=".build/checkouts/ouro-native-apple-app-shell/scripts/check-shell-boundary.sh"
if [[ "${1:-}" == "--selftest" ]]; then
  exec "$checker" --selftest
fi
exec "$checker" --repo "$ROOT_DIR" --allowlist "$ROOT_DIR/scripts/shell-boundary-allowlist.txt"
EOF
  cat >"$valid/scripts/check-shell-dependency.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo shell dependency ok
EOF
  cat >"$valid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
EOF
  : >"$valid/scripts/shell-boundary-allowlist.txt"
  chmod +x "$valid/scripts/"*.sh

  run_doctor "$valid" fake-consumer ""

  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  rm -rf "$invalid/Tests"
  mkdir -p "$invalid/Tests/FakeAppTests"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-invalid.out 2>/tmp/ouro-shell-doctor-invalid.err; then
    fail "selftest expected missing contract test to fail"
  fi
  grep -Fq "consumer tests must import OuroAppShellConsumerTesting" /tmp/ouro-shell-doctor-invalid.err || fail "selftest did not report missing consumer testing import"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  rm "$invalid/scripts/check-shell-boundary.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-missing-wrapper.out 2>/tmp/ouro-shell-doctor-missing-wrapper.err; then
    fail "selftest expected missing boundary wrapper to fail"
  fi
  grep -Fq "missing scripts/check-shell-boundary.sh" /tmp/ouro-shell-doctor-missing-wrapper.err || fail "selftest did not report missing boundary wrapper"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/check-shell-boundary.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# noop; .build/checkouts/ouro-native-apple-app-shell/scripts/check-shell-boundary.sh --repo "$PWD"
echo ".build/checkouts/ouro-native-apple-app-shell/scripts/check-shell-boundary.sh --repo $PWD"
EOF
  chmod +x "$invalid/scripts/check-shell-boundary.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-echo-wrapper.out 2>/tmp/ouro-shell-doctor-echo-wrapper.err; then
    fail "selftest expected echo-only boundary wrapper to fail"
  fi
  grep -Fq "scripts/check-shell-boundary.sh must delegate to the shell scanner with --repo" /tmp/ouro-shell-doctor-echo-wrapper.err || fail "selftest did not report echo-only boundary wrapper"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/check-shell-boundary.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
true || .build/checkouts/ouro-native-apple-app-shell/scripts/check-shell-boundary.sh --repo "$PWD"
EOF
  chmod +x "$invalid/scripts/check-shell-boundary.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-short-circuit-wrapper.out 2>/tmp/ouro-shell-doctor-short-circuit-wrapper.err; then
    fail "selftest expected short-circuited boundary wrapper to fail"
  fi
  grep -Fq "scripts/check-shell-boundary.sh must delegate to the shell scanner with --repo" /tmp/ouro-shell-doctor-short-circuit-wrapper.err || fail "selftest did not report short-circuited boundary wrapper"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/check-shell-boundary.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
unused_delegate() {
  .build/checkouts/ouro-native-apple-app-shell/scripts/check-shell-boundary.sh --repo "$PWD"
}
EOF
  chmod +x "$invalid/scripts/check-shell-boundary.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-function-wrapper.out 2>/tmp/ouro-shell-doctor-function-wrapper.err; then
    fail "selftest expected function-only boundary wrapper to fail"
  fi
  grep -Fq "scripts/check-shell-boundary.sh must delegate to the shell scanner with --repo" /tmp/ouro-shell-doctor-function-wrapper.err || fail "selftest did not report function-only boundary wrapper"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/check-shell-boundary.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker=".build/checkouts/ouro-native-apple-app-shell/scripts/check-shell-boundary.sh"
exec "$checker" --repo "$ROOT_DIR" --allowlist "$ROOT_DIR/scripts/shell-boundary-allowlist.txt"
EOF
  chmod +x "$invalid/scripts/check-shell-boundary.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-dropped-selftest-wrapper.out 2>/tmp/ouro-shell-doctor-dropped-selftest-wrapper.err; then
    fail "selftest expected dropped boundary wrapper selftest to fail"
  fi
  grep -Fq "scripts/check-shell-boundary.sh --selftest must run the shell scanner selftest" /tmp/ouro-shell-doctor-dropped-selftest-wrapper.err || fail "selftest did not report dropped boundary wrapper selftest"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/check-shell-boundary.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker=".build/checkouts/ouro-native-apple-app-shell/scripts/check-shell-boundary.sh"
if [[ "${1:-}" == "--selftest" ]]; then
  exec "$checker" --selftest
fi
exit 0
exec "$checker" --repo "$ROOT_DIR" --allowlist "$ROOT_DIR/scripts/shell-boundary-allowlist.txt"
EOF
  chmod +x "$invalid/scripts/check-shell-boundary.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-dropped-scan-wrapper.out 2>/tmp/ouro-shell-doctor-dropped-scan-wrapper.err; then
    fail "selftest expected dropped boundary wrapper scan to fail"
  fi
  grep -Fq "scripts/check-shell-boundary.sh must delegate to the shell scanner with --repo" /tmp/ouro-shell-doctor-dropped-scan-wrapper.err || fail "selftest did not report dropped boundary wrapper scan"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/check-shell-boundary.sh" <<'EOF'
#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker=".build/checkouts/ouro-native-apple-app-shell/scripts/check-shell-boundary.sh"
if [[ "${1:-}" == "--selftest" ]]; then
  exec "$checker" --selftest
fi
exec "$checker" --repo "$ROOT_DIR" --allowlist "$ROOT_DIR/scripts/shell-boundary-allowlist.txt"
EOF
  chmod +x "$invalid/scripts/check-shell-boundary.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-wrapper-no-fail-fast.out 2>/tmp/ouro-shell-doctor-wrapper-no-fail-fast.err; then
    fail "selftest expected boundary wrapper without fail-fast to fail"
  fi
  grep -Fq "scripts/check-shell-boundary.sh must enable fail-fast shell mode" /tmp/ouro-shell-doctor-wrapper-no-fail-fast.err || fail "selftest did not report boundary wrapper fail-fast miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# scripts/check-shell-dependency.sh
# scripts/check-shell-boundary.sh --selftest
# scripts/check-shell-boundary.sh
echo "not really checking shell adoption"
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-comment-preflight.out 2>/tmp/ouro-shell-doctor-comment-preflight.err; then
    fail "selftest expected comment-only preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-comment-preflight.err || fail "selftest did not report missing active preflight dependency check"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
true # noop; scripts/check-shell-dependency.sh
true # noop; scripts/check-shell-boundary.sh --selftest
true # noop; scripts/check-shell-boundary.sh
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-inline-comment-preflight.out 2>/tmp/ouro-shell-doctor-inline-comment-preflight.err; then
    fail "selftest expected inline-comment-only preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-inline-comment-preflight.err || fail "selftest did not report inline-comment preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo scripts/check-shell-dependency.sh
echo scripts/check-shell-boundary.sh --selftest
echo scripts/check-shell-boundary.sh
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-echo-preflight.out 2>/tmp/ouro-shell-doctor-echo-preflight.err; then
    fail "selftest expected echoed preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-echo-preflight.err || fail "selftest did not report echoed preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'DOC'
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
DOC
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-heredoc-preflight.out 2>/tmp/ouro-shell-doctor-heredoc-preflight.err; then
    fail "selftest expected heredoc-only preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-heredoc-preflight.err || fail "selftest did not report heredoc preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'DOC' || true
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
DOC
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-heredoc-separator-preflight.out 2>/tmp/ouro-shell-doctor-heredoc-separator-preflight.err; then
    fail "selftest expected heredoc-with-separator preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-heredoc-separator-preflight.err || fail "selftest did not report heredoc-with-separator preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec true
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-exec-preflight.out 2>/tmp/ouro-shell-doctor-exec-preflight.err; then
    fail "selftest expected exec-before-checks preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-exec-preflight.err || fail "selftest did not report exec-before-checks preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command exec true
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-command-exec-preflight.out 2>/tmp/ouro-shell-doctor-command-exec-preflight.err; then
    fail "selftest expected command-exec-before-checks preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-command-exec-preflight.err || fail "selftest did not report command-exec-before-checks preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
true || scripts/check-shell-dependency.sh
true || scripts/check-shell-boundary.sh --selftest
true || scripts/check-shell-boundary.sh
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-short-circuit-preflight.out 2>/tmp/ouro-shell-doctor-short-circuit-preflight.err; then
    fail "selftest expected short-circuited preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-short-circuit-preflight.err || fail "selftest did not report short-circuited preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-exit-preflight.out 2>/tmp/ouro-shell-doctor-exit-preflight.err; then
    fail "selftest expected exit-before-checks preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-exit-preflight.err || fail "selftest did not report exit-before-checks preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
scripts/check-shell-dependency.sh || true
scripts/check-shell-boundary.sh --selftest || true
scripts/check-shell-boundary.sh || true
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-masked-preflight.out 2>/tmp/ouro-shell-doctor-masked-preflight.err; then
    fail "selftest expected masked preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-masked-preflight.err || fail "selftest did not report masked preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
set +e
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
exit 0
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-errexit-disabled-preflight.out 2>/tmp/ouro-shell-doctor-errexit-disabled-preflight.err; then
    fail "selftest expected errexit-disabled preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-errexit-disabled-preflight.err || fail "selftest did not report errexit-disabled preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-err-trap-preflight.out 2>/tmp/ouro-shell-doctor-err-trap-preflight.err; then
    fail "selftest expected ERR-trapped preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-err-trap-preflight.err || fail "selftest did not report ERR-trapped preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
trap 'exit 0' ERR
set -euo pipefail
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-early-err-trap-preflight.out 2>/tmp/ouro-shell-doctor-early-err-trap-preflight.err; then
    fail "selftest expected early-ERR-trapped preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-early-err-trap-preflight.err || fail "selftest did not report early-ERR-trapped preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-preflight-no-fail-fast.out 2>/tmp/ouro-shell-doctor-preflight-no-fail-fast.err; then
    fail "selftest expected preflight without fail-fast to fail"
  fi
  grep -Fq "scripts/preflight.sh must enable fail-fast shell mode" /tmp/ouro-shell-doctor-preflight-no-fail-fast.err || fail "selftest did not report preflight fail-fast miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/pr-preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
scripts/check-shell-dependency.sh
scripts/check-shell-boundary.sh --selftest
scripts/check-shell-boundary.sh
EOF
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "not really checking shell adoption"
EOF
  chmod +x "$invalid/scripts/pr-preflight.sh" "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-two-preflights.out 2>/tmp/ouro-shell-doctor-two-preflights.err; then
    fail "selftest expected inert second preflight entrypoint to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-two-preflights.err || fail "selftest did not report inert second preflight entrypoint"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
unused_shell_checks() {
  scripts/check-shell-dependency.sh
  scripts/check-shell-boundary.sh --selftest
  scripts/check-shell-boundary.sh
}
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-function-preflight.out 2>/tmp/ouro-shell-doctor-function-preflight.err; then
    fail "selftest expected function-only preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-function-preflight.err || fail "selftest did not report function-only preflight dependency miss"

  rm -rf "$invalid"
  mkdir -p "$invalid"
  cp -R "$valid/." "$invalid"
  cat >"$invalid/scripts/preflight.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if false; then
  scripts/check-shell-dependency.sh
  scripts/check-shell-boundary.sh --selftest
  scripts/check-shell-boundary.sh
fi
EOF
  chmod +x "$invalid/scripts/preflight.sh"
  if run_doctor "$invalid" fake-consumer "" >/tmp/ouro-shell-doctor-conditional-preflight.out 2>/tmp/ouro-shell-doctor-conditional-preflight.err; then
    fail "selftest expected conditional-only preflight wiring to fail"
  fi
  grep -Fq "scripts/preflight.sh must run scripts/check-shell-dependency.sh" /tmp/ouro-shell-doctor-conditional-preflight.err || fail "selftest did not report conditional-only preflight dependency miss"

  mkdir -p "$invalid-boundary"
  cp -R "$valid/." "$invalid-boundary"
  cat >"$invalid-boundary/Sources/FakeApp/LeakyShellView.swift" <<'EOF'
import SwiftUI
import OuroAppShellUI

func leaky() -> some View {
    AppShellAboutView(model: AppShellAboutModel(appName: "Fake", versionLine: "1.0.0", subtitle: "Fake"))
}
EOF
  if run_doctor "$invalid-boundary" fake-consumer "" >/tmp/ouro-shell-doctor-boundary.out 2>/tmp/ouro-shell-doctor-boundary.err; then
    fail "selftest expected shell UI boundary violation to fail"
  fi
  grep -Fq "Shell boundary violations found" /tmp/ouro-shell-doctor-boundary.err || fail "selftest did not report boundary violation"

  printf 'Shell doctor selftest ok\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      [ "$#" -ge 2 ] || fail "--repo requires a path"
      REPO="$2"
      shift 2
      ;;
    --consumer)
      [ "$#" -ge 2 ] || fail "--consumer requires a name"
      CONSUMER="$2"
      shift 2
      ;;
    --allowlist)
      [ "$#" -ge 2 ] || fail "--allowlist requires a file"
      ALLOWLIST="$2"
      shift 2
      ;;
    --selftest)
      run_selftest
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

[ -n "$REPO" ] || {
  usage
  exit 64
}

run_doctor "$REPO" "$CONSUMER" "$ALLOWLIST"
