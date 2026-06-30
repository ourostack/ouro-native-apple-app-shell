#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "visual-surface-manifest.json"
PROBE = ROOT / "Sources" / "OuroAppShellUISurfaceProbe" / "main.swift"
REQUIRED_SURFACES = {"about", "releaseUpdates", "settings", "keyboardShortcuts", "windowChrome"}
VALIDATION_TOOLS = {"shellSurfaceProbe", "appHarness", "accessibilityTree", "screenshotOCR", "viewInspector"}


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def probe_names() -> set[str]:
    text = PROBE.read_text()
    literal_names = {
        name for name in re.findall(r'name:\s*"([^"]+)"', text)
        if "\\(" not in name
    }
    literal_names.update(f"updates-{state}" for state in [
        "notChecked",
        "checking",
        "current",
        "updateAvailable",
        "installing",
        "readyToRelaunch",
        "installed",
        "unavailable",
        "failed",
    ])
    return literal_names


def main() -> None:
    if not MANIFEST.exists():
        fail(f"missing visual surface manifest: {MANIFEST}")

    try:
        data = json.loads(MANIFEST.read_text())
    except json.JSONDecodeError as error:
        fail(f"invalid manifest JSON: {error}")

    rows = data.get("surfaces")
    if not isinstance(rows, list) or not rows:
        fail("manifest must contain a non-empty 'surfaces' array")

    manifest_names: set[str] = set()
    manifest_surfaces: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            fail(f"surface row {index} must be an object")
        for key in ["id", "surface", "state", "validationTool", "owner"]:
            if not str(row.get(key, "")).strip():
                fail(f"surface row {index} missing {key}")
        if row["validationTool"] not in VALIDATION_TOOLS:
            fail(f"surface row {row['id']} has unknown validationTool {row['validationTool']}")
        manifest_names.add(row["id"])
        manifest_surfaces.add(row["surface"])

    missing_surfaces = REQUIRED_SURFACES - manifest_surfaces
    if missing_surfaces:
        fail("manifest missing required surfaces: " + ", ".join(sorted(missing_surfaces)))

    missing_probe_names = probe_names() - manifest_names
    if missing_probe_names:
        fail("manifest missing shell probe rows: " + ", ".join(sorted(missing_probe_names)))

    print("Visual surface manifest: ok")


if __name__ == "__main__":
    main()
