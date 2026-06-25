#!/usr/bin/env bash
#
# Coverage gate for shared shell logic contracts.
#
# The shell core plus public UI model/state contracts are shared by native apps,
# so they must be 100% line and region covered. Swift exposes branch-like
# coverage through regions. SwiftUI view bodies are rendered by
# scripts/ui-surface-probe.sh instead of line-covered here.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

CORE_DIR="Sources/OuroAppShellCore"
UI_CONTRACT_FILES=(
  "Sources/OuroAppShellUI/AppShellAboutModel.swift"
  "Sources/OuroAppShellUI/ReleaseUpdateViewState.swift"
)

if [ -d /Applications ]; then
  latest="$(ls -d /Applications/Xcode_16*.app 2>/dev/null | sort -V | tail -1 || true)"
  [ -z "${latest:-}" ] && latest="$(ls -d /Applications/Xcode_*.app 2>/dev/null | sort -V | tail -1 || true)"
  [ -n "${latest:-}" ] && export DEVELOPER_DIR="$latest/Contents/Developer"
fi

if [ "${1:-}" != "--no-build" ]; then
  echo "==> swift test --enable-code-coverage"
  swift test --enable-code-coverage -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
fi

bin="$(find .build -path '*/OuroAppShellPackageTests.xctest/Contents/MacOS/OuroAppShellPackageTests' -type f ! -path '*dSYM*' | head -1)"
prof="$(find .build -path '*/codecov/default.profdata' -type f | head -1)"
if [ -z "$bin" ] || [ -z "$prof" ]; then
  echo "error: could not locate coverage artifacts (binary='$bin' profdata='$prof')" >&2
  exit 1
fi

xcrun llvm-cov export "$bin" -instr-profile "$prof" -summary-only "$CORE_DIR" "${UI_CONTRACT_FILES[@]}" > .build/ouro-app-shell-coverage.json

python3 - "$CORE_DIR" "${UI_CONTRACT_FILES[@]}" <<'PY'
import json, os, sys

core_dir = sys.argv[1]
ui_contract_files = sys.argv[2:]
with open('.build/ouro-app-shell-coverage.json') as fh:
    data = json.load(fh)

coverage_files = data['data'][0]['files']
core_files = [f for f in coverage_files if f'/{core_dir}/' in f['filename']]
if not core_files:
    print(f'error: no {core_dir} files in coverage data', file=sys.stderr)
    sys.exit(1)

def matching_file(path):
    suffix = f'/{path}'
    matches = [f for f in coverage_files if f['filename'].endswith(suffix)]
    if not matches:
        print(f'error: no {path} file in coverage data', file=sys.stderr)
        sys.exit(1)
    if len(matches) > 1:
        print(f'error: multiple coverage files match {path}', file=sys.stderr)
        sys.exit(1)
    return matches[0]

ui_files = [matching_file(path) for path in ui_contract_files]

below = []
def collect_below(files, group):
    for f in files:
        name = os.path.basename(f['filename'])
        lines = f['summary']['lines']
        regions = f['summary']['regions']
        uncovered_lines = lines['count'] - lines['covered']
        uncovered_regions = regions['count'] - regions['covered']
        if uncovered_lines or uncovered_regions:
            below.append((group, uncovered_lines, name, lines['percent'], regions['percent'], uncovered_regions, f['filename']))

collect_below(core_files, 'Core')
collect_below(ui_files, 'UI contract')

def print_group(label, files):
    failing = {
        path for group, _, _, _, _, _, path in below
        if any(path == f['filename'] for f in files)
    }
    print(f'\n{label}: {len(files) - len(failing)}/{len(files)} files at 100% line+region')

print_group('OuroAppShellCore', core_files)
print_group('OuroAppShellUI contracts', ui_files)
print('OuroAppShellUI rendered views: guarded by scripts/ui-surface-probe.sh')

with open('.build/ouro-app-shell-below.txt', 'w') as fh:
    if below:
        below.sort(reverse=True)
        print(f'\n{len(below)} below 100%:')
        for group, uncovered_lines, name, line_percent, region_percent, uncovered_regions, path in below:
            print(f'  [{group}] {name:34} {line_percent:5.1f}% line  {region_percent:5.1f}% region  ({uncovered_lines} lines / {uncovered_regions} regions uncovered)')
            fh.write(path + '\n')
PY

if [ -s .build/ouro-app-shell-below.txt ]; then
  echo ""
  echo "==> uncovered detail:"
  while IFS= read -r srcfile; do
    [ -n "$srcfile" ] || continue
    echo ""
    echo "--- $srcfile ---"
    echo "  uncovered LINES:"
    xcrun llvm-cov show "$bin" -instr-profile "$prof" "$srcfile" 2>/dev/null \
      | grep -E '^\s*[0-9]+\|\s*0\|' | sed 's/^/    /' || echo "    (none fully-uncovered; gaps are partial regions)"
    echo "  uncovered REGIONS:"
    xcrun llvm-cov show "$bin" -instr-profile "$prof" "$srcfile" --show-regions 2>/dev/null \
      | grep -B1 -E '^\s+\^0([^0-9]|$)' | grep -vE '^\s+\^0|^--' | sed 's/^/    /' | head -40 || true
  done < .build/ouro-app-shell-below.txt
  echo ""
  echo "FAIL: OuroAppShellCore and OuroAppShellUI contracts must be 100% line + region covered."
  exit 1
fi

echo ""
echo "PASS: OuroAppShellCore and OuroAppShellUI contracts are 100% line + region covered."
echo "PASS: SwiftUI rendered views remain guarded by scripts/ui-surface-probe.sh."
