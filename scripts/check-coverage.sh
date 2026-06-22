#!/usr/bin/env bash
#
# Coverage gate for OuroAppShellCore.
#
# The shell core is shared by native apps, so every source file must be 100%
# line and region covered. Swift exposes branch-like coverage through regions.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

CORE_DIR="Sources/OuroAppShellCore"

if [ -d /Applications ]; then
  latest="$(ls -d /Applications/Xcode_16*.app 2>/dev/null | sort -V | tail -1 || true)"
  [ -z "${latest:-}" ] && latest="$(ls -d /Applications/Xcode_*.app 2>/dev/null | sort -V | tail -1 || true)"
  [ -n "${latest:-}" ] && export DEVELOPER_DIR="$latest/Contents/Developer"
fi

if [ "${1:-}" != "--no-build" ]; then
  echo "==> swift test --enable-code-coverage"
  swift test --enable-code-coverage -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
fi

bin="$(find .build -name '*PackageTests' -type f -path '*MacOS*' ! -path '*dSYM*' | head -1)"
prof="$(find .build -name 'default.profdata' | head -1)"
if [ -z "$bin" ] || [ -z "$prof" ]; then
  echo "error: could not locate coverage artifacts (binary='$bin' profdata='$prof')" >&2
  exit 1
fi

xcrun llvm-cov export "$bin" -instr-profile "$prof" -summary-only "$CORE_DIR" > .build/ouro-app-shell-coverage.json

python3 - "$CORE_DIR" <<'PY'
import json, os, sys

core_dir = sys.argv[1]
with open('.build/ouro-app-shell-coverage.json') as fh:
    data = json.load(fh)

files = [f for f in data['data'][0]['files'] if f'/{core_dir}/' in f['filename']]
if not files:
    print(f'error: no {core_dir} files in coverage data', file=sys.stderr)
    sys.exit(1)

below = []
for f in files:
    name = os.path.basename(f['filename'])
    lines = f['summary']['lines']
    regions = f['summary']['regions']
    uncovered_lines = lines['count'] - lines['covered']
    uncovered_regions = regions['count'] - regions['covered']
    if uncovered_lines or uncovered_regions:
        below.append((uncovered_lines, name, lines['percent'], regions['percent'], uncovered_regions, f['filename']))

print(f'\nOuroAppShellCore: {len(files) - len(below)}/{len(files)} files at 100% line+region')
with open('.build/ouro-app-shell-below.txt', 'w') as fh:
    if below:
        below.sort(reverse=True)
        print(f'\n{len(below)} below 100%:')
        for uncovered_lines, name, line_percent, region_percent, uncovered_regions, path in below:
            print(f'  {name:44} {line_percent:5.1f}% line  {region_percent:5.1f}% region  ({uncovered_lines} lines / {uncovered_regions} regions uncovered)')
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
  echo "FAIL: OuroAppShellCore must be 100% line + region covered."
  exit 1
fi

echo ""
echo "PASS: OuroAppShellCore is 100% line + region covered."
