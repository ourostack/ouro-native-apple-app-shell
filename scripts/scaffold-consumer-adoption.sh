#!/usr/bin/env bash
#
# Generate a minimal downstream native app fixture wired to the shared Ouro app
# shell contract. This is the executable "copy this shape" path for new
# consumers: Package dependency, typed contract, consumer tests, boundary
# wrapper, dependency guard, and preflight ordering.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat >&2 <<'USAGE'
Usage:
  scaffold-consumer-adoption.sh --output PATH --package-name NAME --module-name NAME --app-name NAME --bundle-id ID --repository OWNER/REPO [options]
  scaffold-consumer-adoption.sh --selftest

Options:
  --dependency-mode local|remote   Default: local.
  --shell-path PATH                Local dependency path. Default: this repo.
  --shell-url URL                  Remote dependency URL. Default: canonical shell repo.
  --shell-revision SHA             Remote Package.resolved revision. Default: origin/main when available.
  --force                          Replace an existing output directory.

The generated fixture is intentionally small, but it satisfies scripts/shell-doctor.sh.
Use it as the reference shape when wiring a real Ouro native app to the shell.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

shell_main_revision() {
  local url="$1"
  local revision=""
  revision="$(git ls-remote "$url" refs/heads/main 2>/dev/null | awk 'NR == 1 {print $1}' || true)"
  if [ -z "$revision" ] && git -C "$ROOT" rev-parse --verify origin/main >/dev/null 2>&1; then
    revision="$(git -C "$ROOT" rev-parse origin/main)"
  fi
  if [ -z "$revision" ]; then
    revision="$(git -C "$ROOT" rev-parse HEAD)"
  fi
  printf '%s\n' "$revision"
}

run_generator() {
  python3 - "$@" <<'PY'
import argparse
import json
import os
import pathlib
import re
import shutil
import stat
import sys
import textwrap


def swift_string(value: str) -> str:
    return json.dumps(value)


def swift_identifier(value: str) -> str:
    parts = re.findall(r"[A-Za-z0-9]+", value)
    identifier = "".join(part[:1].upper() + part[1:] for part in parts) or "ConsumerApp"
    if identifier[0].isdigit():
        identifier = "App" + identifier
    return identifier


def write(path: pathlib.Path, text: str, executable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(text).lstrip(), encoding="utf-8")
    if executable:
        path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


parser = argparse.ArgumentParser()
parser.add_argument("--output", required=True)
parser.add_argument("--package-name", required=True)
parser.add_argument("--module-name", required=True)
parser.add_argument("--app-name", required=True)
parser.add_argument("--bundle-id", required=True)
parser.add_argument("--repository", required=True)
parser.add_argument("--dependency-mode", choices=["local", "remote"], required=True)
parser.add_argument("--shell-path", required=True)
parser.add_argument("--shell-url", required=True)
parser.add_argument("--shell-revision", required=True)
parser.add_argument("--force", action="store_true")
args = parser.parse_args()

output = pathlib.Path(args.output).expanduser().resolve()
if output.exists():
    if not args.force:
        raise SystemExit(f"refusing to overwrite existing output without --force: {output}")
    shutil.rmtree(output)
output.mkdir(parents=True)

module = swift_identifier(args.module_name)
contract_type = f"{module}ShellContract"
package_name = args.package_name
archive_prefix = re.sub(r"[^A-Za-z0-9]+", "", args.app_name) or module
repo_url = f"https://github.com/{args.repository}"
shell_path = pathlib.Path(args.shell_path).expanduser().resolve()
local_boundary_checker = str(shell_path / "scripts" / "check-shell-boundary.sh") if args.dependency_mode == "local" else ""

if args.dependency_mode == "local":
    dependency_line = f'.package(name: "ouro-native-apple-app-shell", path: {swift_string(str(shell_path))})'
else:
    dependency_line = f'.package(url: {swift_string(args.shell_url)}, branch: "main")'

write(
    output / "Package.swift",
    f"""
    // swift-tools-version: 6.0
    import PackageDescription

    let package = Package(
        name: {swift_string(package_name)},
        platforms: [.macOS(.v13)],
        dependencies: [
            {dependency_line}
        ],
        targets: [
            .target(
                name: {swift_string(module)},
                dependencies: [
                    .product(name: "OuroAppShellContract", package: "ouro-native-apple-app-shell")
                ]
            ),
            .testTarget(
                name: {swift_string(module + "Tests")},
                dependencies: [
                    {swift_string(module)},
                    .product(name: "OuroAppShellConsumerTesting", package: "ouro-native-apple-app-shell")
                ]
            )
        ]
    )
    """,
)

if args.dependency_mode == "remote":
    package_resolved = {
        "pins": [
            {
                "identity": "ouro-native-apple-app-shell",
                "kind": "remoteSourceControl",
                "location": args.shell_url,
                "state": {
                    "branch": "main",
                    "revision": args.shell_revision,
                },
            }
        ],
        "version": 3,
    }
    write(output / "Package.resolved", json.dumps(package_resolved, indent=2) + "\n")

write(
    output / "Sources" / module / f"{contract_type}.swift",
    f"""
    import Foundation
    import OuroAppShellContract

    enum {contract_type} {{
        static let requiredSurfaces: [AppShellSurface] = [
            .appIdentity,
            .releaseUpdates,
            .about,
            .keyboardShortcuts,
            .settings,
            .windowChrome,
        ]

        static var contract: OuroAppShellContract {{
            OuroAppShellContract(
                identity: AppShellIdentity(
                    appName: {swift_string(args.app_name)},
                    bundleIdentifier: {swift_string(args.bundle_id)},
                    repository: {swift_string(args.repository)},
                    version: "0.1.0"
                ),
                requiredSurfaces: requiredSurfaces,
                releaseUpdates: OuroAppShellReleaseUpdateContract(
                    policy: .stable(
                        assetNamingPolicy: .versionedArchiveAndManifest(namePrefix: {swift_string(archive_prefix + "-")})
                    ),
                    supportsInstallAndRelaunch: true,
                    supportsReleasePage: true
                ),
                about: OuroAppShellAboutContract(
                    subtitle: "Shared shell adoption fixture",
                    repositoryURL: URL(string: {swift_string(repo_url)})
                ),
                commandReference: OuroAppShellCommandReferenceContract(
                    title: "Keyboard Shortcuts",
                    commandCount: 1,
                    sections: ["Global"],
                    entryPoint: "Help > Keyboard Shortcuts"
                ),
                commandManifest: OuroAppShellCommandSurfaceManifest(commands: [
                    OuroAppShellCommandSurface(
                        id: "global.keyboard-shortcuts",
                        title: "Keyboard Shortcuts",
                        section: "Global",
                        shortcut: "⌘/",
                        menuPath: "Help > Keyboard Shortcuts",
                        commandPaletteTitle: "Keyboard Shortcuts",
                        referenceTitle: "Keyboard Shortcuts"
                    )
                ]),
                utilityWindows: [
                    OuroAppShellUtilityWindowContract(id: "about", surface: .about, title: {swift_string("About " + args.app_name)}),
                    OuroAppShellUtilityWindowContract(id: "shortcuts", surface: .keyboardShortcuts, title: "Keyboard Shortcuts"),
                ],
                settings: OuroAppShellSettingsContract(entryPoint: {swift_string(args.app_name + " > Settings")})
            )
        }}
    }}
    """,
)

write(
    output / "Tests" / f"{module}Tests" / f"{contract_type}Tests.swift",
    f"""
    import XCTest
    import OuroAppShellConsumerTesting
    @testable import {module}

    final class {contract_type}Tests: XCTestCase {{
        func testShellContractIsValidAndDeclaresShellFirstSurfaces() {{
            OuroAppShellContractAssertions.assertValid({contract_type}.contract)
            OuroAppShellContractAssertions.assertRequiresShellFirstSurfaces(
                {contract_type}.contract,
                {contract_type}.requiredSurfaces
            )
            OuroAppShellContractAssertions.assertCommandManifestMatchesReference({contract_type}.contract)
        }}
    }}
    """,
)

write(output / "scripts" / "shell-boundary-allowlist.txt", "# path\tpattern\treason\n")

write(
    output / "scripts" / "check-shell-boundary.sh",
    """
    #!/usr/bin/env bash
    set -euo pipefail

    ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    cd "$ROOT_DIR"

    checker=".build/checkouts/ouro-native-apple-app-shell/scripts/check-shell-boundary.sh"
    local_checker=__LOCAL_CHECKER__

    if [[ -n "${OURO_APP_SHELL_ROOT:-}" ]]; then
      checker="$OURO_APP_SHELL_ROOT/scripts/check-shell-boundary.sh"
    fi
    if [[ ! -x "$checker" && -z "${OURO_APP_SHELL_ROOT:-}" ]]; then
      swift package resolve >/dev/null
    fi
    if [[ ! -x "$checker" && -n "$local_checker" && -x "$local_checker" ]]; then
      checker="$local_checker"
    fi

    [[ -x "$checker" ]] || {
      printf 'error: missing shell boundary checker at %s\n' "$checker" >&2
      exit 1
    }

    if [[ "${1:-}" == "--selftest" ]]; then
      exec "$checker" --selftest
    fi

    exec "$checker" --repo "$ROOT_DIR" --allowlist "$ROOT_DIR/scripts/shell-boundary-allowlist.txt"
    """.replace("__LOCAL_CHECKER__", swift_string(local_boundary_checker)),
    executable=True,
)

if args.dependency_mode == "local":
    dependency_check = f"""
    #!/usr/bin/env bash
    set -euo pipefail

    ROOT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")/.." && pwd)"
    cd "$ROOT_DIR"

    python3 - "Package.swift" {swift_string(str(shell_path))} <<'PY'
    import pathlib
    import sys

    manifest = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
    shell_path = sys.argv[2]
    required = [
        'package(name: "ouro-native-apple-app-shell", path:',
        shell_path,
        '.product(name: "OuroAppShellContract", package: "ouro-native-apple-app-shell")',
        '.product(name: "OuroAppShellConsumerTesting", package: "ouro-native-apple-app-shell")',
    ]
    for token in required:
        if token not in manifest:
            raise SystemExit(f"Package.swift missing shell dependency token: {{token}}")
    PY

    echo "shell dependency fresh: local ouro-native-apple-app-shell at {shell_path}"
    """
else:
    dependency_check = f"""
    #!/usr/bin/env bash
    set -euo pipefail

    ROOT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")/.." && pwd)"
    cd "$ROOT_DIR"

    identity="ouro-native-apple-app-shell"
    shell_url={swift_string(args.shell_url)}
    shell_ref="refs/heads/main"
    manifest="Package.swift"
    resolved="Package.resolved"

    fail() {{
      echo "error: $*" >&2
      exit 1
    }}

    [[ -f "$manifest" ]] || fail "missing $manifest"
    [[ -f "$resolved" ]] || fail "missing $resolved"

    python3 - "$manifest" "$shell_url" <<'PY'
    import re
    import sys

    manifest, shell_url = sys.argv[1:]
    text = open(manifest, encoding="utf-8").read()
    pattern = re.compile(
        r'\\.package\\(\\s*url:\\s*"' + re.escape(shell_url) + r'",\\s*branch:\\s*"main"\\s*\\)',
        re.S,
    )
    if not pattern.search(text):
        raise SystemExit(f"Package.swift must depend on {{shell_url}} branch main")
    PY

    pin="$(
      python3 - "$resolved" "$identity" "$shell_url" <<'PY'
    import json
    import sys

    resolved, identity, shell_url = sys.argv[1:]
    with open(resolved, encoding="utf-8") as fh:
        data = json.load(fh)

    for pin in data.get("pins", []):
        if pin.get("identity") == identity:
            location = pin.get("location") or ""
            if location != shell_url:
                raise SystemExit(f"{{identity}} pin location mismatch: {{location or '<none>'}}, expected {{shell_url}}")
            state = pin.get("state", {{}})
            branch = state.get("branch") or ""
            revision = state.get("revision") or ""
            if not revision:
                raise SystemExit(f"{{identity}} pin is missing state.revision")
            print(f"{{branch}}\\t{{revision}}")
            break
    else:
        raise SystemExit(f"Package.resolved has no pin for {{identity}}")
    PY
    )"

    branch="${{pin%%$'\\t'*}}"
    resolved_revision="${{pin#*$'\\t'}}"
    [[ "$branch" == "main" ]] || fail "$identity must resolve branch main, got '${{branch:-<none>}}'"

    remote_revision="$(git ls-remote "$shell_url" "$shell_ref" | awk 'NR == 1 {{print $1}}')"
    [[ -n "$remote_revision" ]] || fail "could not resolve $shell_url $shell_ref"

    if [[ "$resolved_revision" != "$remote_revision" ]]; then
      cat >&2 <<EOF
    error: $identity is stale in Package.resolved
      resolved: $resolved_revision
      remote:   $remote_revision

    Run:
      swift package update $identity
    EOF
      exit 1
    fi

    echo "shell dependency fresh: $identity@$resolved_revision"
    """

write(output / "scripts" / "check-shell-dependency.sh", dependency_check, executable=True)

write(
    output / "scripts" / "preflight.sh",
    """
    #!/usr/bin/env bash
    set -euo pipefail

    ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    cd "$ROOT_DIR"

    scripts/check-shell-dependency.sh
    scripts/check-shell-boundary.sh --selftest
    scripts/check-shell-boundary.sh

    TEST_HOME="${OURO_APP_TEST_HOME:-"$ROOT_DIR/.build/ouro-app-test-home"}"
    TEST_TMP="${OURO_APP_TEST_TMPDIR:-"$ROOT_DIR/.build/ouro-app-test-tmp"}"
    mkdir -p "$TEST_HOME/Library/Preferences" "$TEST_HOME/Library/Application Support" "$TEST_TMP"

    env \\
      HOME="$TEST_HOME" \\
      CFFIXED_USER_HOME="$TEST_HOME" \\
      TMPDIR="$TEST_TMP/" \\
      swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
    """,
    executable=True,
)

write(
    output / "README.md",
    f"""
    # {args.app_name} Shell Adoption Fixture

    This fixture is generated by `ouro-native-apple-app-shell/scripts/scaffold-consumer-adoption.sh`.

    It demonstrates the minimum consumer wiring expected by the shared shell:

    - `Package.swift` depends on `ouro-native-apple-app-shell`.
    - `Sources/{module}/{contract_type}.swift` declares a typed `OuroAppShellContract`.
    - `Tests/{module}Tests/{contract_type}Tests.swift` asserts the contract with `OuroAppShellConsumerTesting`.
    - `scripts/check-shell-dependency.sh` guards the dependency shape.
    - `scripts/check-shell-boundary.sh` delegates to the shell-owned scanner.
    - `scripts/preflight.sh` runs shell dependency and boundary checks before other gates.
    - Swift tests run with isolated `HOME`/`CFFIXED_USER_HOME` roots so local app preferences
      cannot affect deterministic test surfaces.

    Validate with:

    ```bash
    scripts/preflight.sh
    ```
    """,
)

print(f"Generated shell consumer adoption fixture at {output}")
PY
}

selftest() {
  local tmp fixture remote_fixture overwrite_out overwrite_err
  tmp="$(mktemp -d)"
  trap "rm -rf '$tmp'" EXIT
  fixture="$tmp/fake-consumer"
  remote_fixture="$tmp/remote-consumer"
  overwrite_out="$tmp/overwrite.out"
  overwrite_err="$tmp/overwrite.err"

  "$0" \
    --output "$fixture" \
    --package-name FakeConsumer \
    --module-name FakeApp \
    --app-name 'Fake "Quoted" Consumer' \
    --bundle-id com.ouro.fake-consumer \
    --repository ourostack/fake-consumer \
    --dependency-mode local \
    --shell-path "$ROOT" \
    --force

  if "$0" \
    --output "$fixture" \
    --package-name FakeConsumer \
    --module-name FakeApp \
    --app-name 'Fake "Quoted" Consumer' \
    --bundle-id com.ouro.fake-consumer \
    --repository ourostack/fake-consumer \
    --dependency-mode local \
    --shell-path "$ROOT" >"$overwrite_out" 2>"$overwrite_err"; then
    fail "selftest expected overwrite without --force to fail"
  fi
  grep -Fq "refusing to overwrite existing output without --force" "$overwrite_err" || fail "selftest did not report overwrite refusal"

  grep -Fq "privacyDiagnostics:" "$fixture/Sources/FakeApp/FakeAppShellContract.swift" || fail "fixture contract must declare privacy diagnostics"
  test -f "$fixture/config/ouro-app-control-deck.json" || fail "fixture must include config/ouro-app-control-deck.json"
  grep -Fq '"local_manifest": "config/ouro-app-control-deck.json"' "$fixture/config/ouro-app-control-deck.json" || fail "fixture control deck must declare local manifest path"

  OURO_APP_SHELL_ROOT="$ROOT" "$ROOT/scripts/shell-doctor.sh" --repo "$fixture" --consumer fake-consumer
  "$fixture/scripts/preflight.sh"

  "$0" \
    --output "$remote_fixture" \
    --package-name RemoteConsumer \
    --module-name RemoteApp \
    --app-name "Remote Consumer" \
    --bundle-id com.ouro.remote-consumer \
    --repository ourostack/remote-consumer \
    --dependency-mode remote \
    --force
  grep -Fq 'local_checker=""' "$remote_fixture/scripts/check-shell-boundary.sh" || fail "remote fixture should not bake a local boundary checker"
  if grep -Fq "$ROOT/scripts/check-shell-boundary.sh" "$remote_fixture/scripts/check-shell-boundary.sh"; then
    fail "remote fixture unexpectedly references the local shell checkout"
  fi
  "$remote_fixture/scripts/check-shell-boundary.sh" --selftest

  printf 'Consumer adoption scaffold selftest ok\n'
}

OUTPUT=""
PACKAGE_NAME=""
MODULE_NAME=""
APP_NAME=""
BUNDLE_ID=""
REPOSITORY=""
DEPENDENCY_MODE="local"
SHELL_PATH="$ROOT"
SHELL_URL="https://github.com/ourostack/ouro-native-apple-app-shell.git"
SHELL_REVISION=""
FORCE="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || fail "--output requires a path"
      OUTPUT="$2"
      shift 2
      ;;
    --package-name)
      [ "$#" -ge 2 ] || fail "--package-name requires a value"
      PACKAGE_NAME="$2"
      shift 2
      ;;
    --module-name)
      [ "$#" -ge 2 ] || fail "--module-name requires a value"
      MODULE_NAME="$2"
      shift 2
      ;;
    --app-name)
      [ "$#" -ge 2 ] || fail "--app-name requires a value"
      APP_NAME="$2"
      shift 2
      ;;
    --bundle-id)
      [ "$#" -ge 2 ] || fail "--bundle-id requires a value"
      BUNDLE_ID="$2"
      shift 2
      ;;
    --repository)
      [ "$#" -ge 2 ] || fail "--repository requires OWNER/REPO"
      REPOSITORY="$2"
      shift 2
      ;;
    --dependency-mode)
      [ "$#" -ge 2 ] || fail "--dependency-mode requires local or remote"
      DEPENDENCY_MODE="$2"
      shift 2
      ;;
    --shell-path)
      [ "$#" -ge 2 ] || fail "--shell-path requires a path"
      SHELL_PATH="$2"
      shift 2
      ;;
    --shell-url)
      [ "$#" -ge 2 ] || fail "--shell-url requires a URL"
      SHELL_URL="$2"
      shift 2
      ;;
    --shell-revision)
      [ "$#" -ge 2 ] || fail "--shell-revision requires a SHA"
      SHELL_REVISION="$2"
      shift 2
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    --selftest)
      selftest
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

case "$DEPENDENCY_MODE" in
  local|remote) ;;
  *) fail "--dependency-mode must be local or remote" ;;
esac

[ -n "$OUTPUT" ] || { usage; exit 64; }
[ -n "$PACKAGE_NAME" ] || fail "--package-name is required"
[ -n "$MODULE_NAME" ] || fail "--module-name is required"
[ -n "$APP_NAME" ] || fail "--app-name is required"
[ -n "$BUNDLE_ID" ] || fail "--bundle-id is required"
[ -n "$REPOSITORY" ] || fail "--repository is required"
[[ "$REPOSITORY" == */* ]] || fail "--repository must be OWNER/REPO"

if [ "$DEPENDENCY_MODE" = "local" ]; then
  [ -d "$SHELL_PATH" ] || fail "--shell-path does not exist: $SHELL_PATH"
fi

if [ -z "$SHELL_REVISION" ]; then
  if [ "$DEPENDENCY_MODE" = "remote" ]; then
    SHELL_REVISION="$(shell_main_revision "$SHELL_URL")"
  else
    SHELL_REVISION="$(git -C "$ROOT" rev-parse HEAD)"
  fi
fi

generator_args=(
  --output "$OUTPUT"
  --package-name "$PACKAGE_NAME"
  --module-name "$MODULE_NAME"
  --app-name "$APP_NAME"
  --bundle-id "$BUNDLE_ID"
  --repository "$REPOSITORY"
  --dependency-mode "$DEPENDENCY_MODE"
  --shell-path "$SHELL_PATH"
  --shell-url "$SHELL_URL"
  --shell-revision "$SHELL_REVISION"
)

if [ "$FORCE" = "true" ]; then
  generator_args+=(--force)
fi

run_generator "${generator_args[@]}"
