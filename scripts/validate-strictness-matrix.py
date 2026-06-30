#!/usr/bin/env python3
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MATRIX = ROOT / "docs" / "swift-strictness-matrix.md"
REPOS = {
    "ouro-native-apple-app-shell": ROOT,
    "ouro-md": Path("../ouro-md-james-policy").resolve(),
    "ouro-workbench": Path("../ouro-workbench-james-policy").resolve(),
}


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def target_names(package: Path) -> list[str]:
    text = package.read_text()
    return re.findall(r"\.(?:target|executableTarget|testTarget)\(\s*name:\s*\"([^\"]+)\"", text)


def main() -> None:
    if not MATRIX.exists():
        fail(f"missing strictness matrix: {MATRIX}")

    matrix = MATRIX.read_text()
    missing: list[str] = []
    for repo, path in REPOS.items():
        package = path / "Package.swift"
        if not package.exists():
            fail(f"missing Package.swift for {repo}: {package}")
        for target in target_names(package):
            marker = f"| `{repo}` | `{target}` |"
            if marker not in matrix:
                missing.append(marker)

    required_phrases = [
        "current language mode",
        "target posture",
        "blockers",
        "validation command",
    ]
    for phrase in required_phrases:
        if phrase not in matrix.lower():
            missing.append(f"matrix phrase: {phrase}")

    if missing:
        fail("strictness matrix is missing entries:\n" + "\n".join(missing))

    print("Swift strictness matrix: ok")


if __name__ == "__main__":
    main()
