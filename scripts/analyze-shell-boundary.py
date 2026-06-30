#!/usr/bin/env python3
import argparse
import pathlib
import re
import sys
from typing import Optional

PROTECTED_IMPORTS = {"OuroAppShellUI", "OuroAppShellAppKit"}
PROTECTED_SYMBOLS = (
    "AppShellAboutView",
    "AppShellCommandReferenceView",
    "ReleaseUpdateControls",
    "ReleaseUpdateViewState",
    "ReleaseUpdateActions",
    "UpdateInstalledConfirmationView",
    "AppShellWindowSpec",
)


def allowlist_rows(path: Optional[pathlib.Path]) -> set[str]:
    if path is None or not path.exists():
        return set()
    allowed: set[str] = set()
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        fields = raw_line.split("\t")
        if len(fields) >= 2 and fields[1] == "typed-analyzer":
            allowed.add(fields[0])
    return allowed


def is_adapter_path(rel: str) -> bool:
    return (
        "ShellAdapter" in rel
        or "ShellPresentation" in rel
        or rel.endswith("AppInfoView.swift")
    )


def is_contract_path(rel: str) -> bool:
    return "ShellContract" in pathlib.Path(rel).name or rel.endswith("AppShellContract.swift")


def imports(source: str) -> set[str]:
    return set(re.findall(r"^\s*import\s+([A-Za-z0-9_]+)", source, flags=re.MULTILINE))


def symbol_count(source: str) -> int:
    return sum(source.count(symbol) for symbol in PROTECTED_SYMBOLS)


def analyze(repo: pathlib.Path, adapter_symbol_limit: int, allowlist: set[str]) -> list[str]:
    sources = repo / "Sources"
    if not sources.exists():
        return []

    violations: list[str] = []
    for path in sorted(sources.rglob("*.swift")):
        rel = path.relative_to(repo).as_posix()
        if rel in allowlist:
            continue
        source = path.read_text(encoding="utf-8")
        file_imports = imports(source)
        protected_imports = sorted(file_imports.intersection(PROTECTED_IMPORTS))
        protected_symbol_count = symbol_count(source)

        if is_contract_path(rel) and (protected_imports or protected_symbol_count):
            reason = (
                f"shell UI/AppKit modules: {', '.join(protected_imports)}"
                if protected_imports
                else f"{protected_symbol_count} shell presentation symbol(s)"
            )
            violations.append(
                f"{rel}\tcontract files may import OuroAppShellContract/Core, not {reason}"
            )
            continue

        if is_adapter_path(rel):
            if protected_symbol_count > adapter_symbol_limit:
                violations.append(
                    f"{rel}\tadapter shell symbol count {protected_symbol_count} exceeds limit {adapter_symbol_limit}; move reusable presentation behavior into the shell"
                )
            continue

    return violations


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".")
    parser.add_argument("--allowlist")
    parser.add_argument("--adapter-symbol-limit", type=int, default=80)
    args = parser.parse_args()

    repo = pathlib.Path(args.repo).resolve()
    allowlist = allowlist_rows(pathlib.Path(args.allowlist).resolve() if args.allowlist else None)
    violations = analyze(repo, args.adapter_symbol_limit, allowlist)
    if violations:
        print(f"Typed shell boundary violations found in {repo}:", file=sys.stderr)
        print("", file=sys.stderr)
        for violation in violations:
            print(f"  {violation}", file=sys.stderr)
        print(
            "\nKeep reusable shell UI/presentation behavior in ouro-native-apple-app-shell; consumers should expose only typed adapter glue and manifests.",
            file=sys.stderr,
        )
        return 1

    print(f"Typed shell boundary scan ok: {repo}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
