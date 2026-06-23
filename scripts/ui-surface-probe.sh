#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ -d /Applications ]; then
  latest="$(ls -d /Applications/Xcode_16*.app 2>/dev/null | sort -V | tail -1 || true)"
  [ -z "${latest:-}" ] && latest="$(ls -d /Applications/Xcode_*.app 2>/dev/null | sort -V | tail -1 || true)"
  [ -n "${latest:-}" ] && export DEVELOPER_DIR="$latest/Contents/Developer"
fi

swift run \
  -Xswiftc -warnings-as-errors \
  -Xswiftc -strict-concurrency=complete \
  OuroAppShellUISurfaceProbe
