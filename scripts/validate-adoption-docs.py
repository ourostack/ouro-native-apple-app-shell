#!/usr/bin/env python3
"""Validate shell adoption docs mention the executable third-app path."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


REQUIREMENTS = {
    "README.md": [
        "scripts/scaffold-consumer-adoption.sh --output",
        "config/ouro-app-control-deck.json",
        "privacy/diagnostics descriptors",
        "OuroAppShellContract",
        "OuroAppShellConsumerTesting",
        "OuroAppShellCore",
    ],
    "docs/INDEX.md": [
        "Privacy And Diagnostics Contract",
        "Third-app adoption quick start",
        "config/ouro-app-control-deck.json",
    ],
    "docs/shell-boundary.md": [
        "config/ouro-app-control-deck.json",
        "privacy/diagnostics",
        "scripts/scaffold-consumer-adoption.sh",
    ],
    "docs/privacy-diagnostics-contract.md": [
        "scripts/scaffold-consumer-adoption.sh",
        "OuroAppShellPrivacyDiagnosticsContract",
        "supportBundleContents",
        "redactionGuarantees",
    ],
}


def main() -> int:
    missing: list[str] = []
    for relative_path, tokens in REQUIREMENTS.items():
        path = ROOT / relative_path
        try:
            text = path.read_text(encoding="utf-8")
        except FileNotFoundError:
            missing.append(f"{relative_path}: missing file")
            continue
        for token in tokens:
            if token not in text:
                missing.append(f"{relative_path}: missing {token!r}")

    if missing:
        print("Adoption docs validation failed:", file=sys.stderr)
        for item in missing:
            print(f"  - {item}", file=sys.stderr)
        return 1

    print("Adoption docs validation ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
