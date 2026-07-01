# Setup Research

## Current Shape

- `scripts/scaffold-consumer-adoption.sh` generates a minimal SwiftPM consumer package with `OuroAppShellContract`, `OuroAppShellConsumerTesting`, a shell-boundary wrapper, a dependency guard, a preflight script, and README.
- The generated contract currently covers identity, release updates, About, command reference, command manifest, utility windows, and settings.
- The generated fixture does not yet declare `privacyDiagnostics` or create an app-local control deck at `config/ouro-app-control-deck.json`.
- `scripts/shell-doctor.sh` statically validates dependency shape, typed contract source, contract tests, dependency/boundary scripts, and preflight ordering.
- `scripts/downstream-consumers.json` is the shell-owned downstream control deck for Ouro MD and Ouro Workbench and references each app-local control deck path.
- README and docs index mention scaffold/doctor/downstream checks, but the cold-start path can be crisper about privacy/diagnostics and control-deck expectations.

## Source Targets

- Scaffold generator: `scripts/scaffold-consumer-adoption.sh`
- Adoption checker: `scripts/shell-doctor.sh`
- Docs: `README.md`, `docs/INDEX.md`, `docs/shell-boundary.md`, `docs/privacy-diagnostics-contract.md`
- Control deck manifest: `scripts/downstream-consumers.json`
- Contract types: `Sources/OuroAppShellContract/OuroAppShellContract.swift`
- Consumer test helpers: `Sources/OuroAppShellConsumerTesting/OuroAppShellContractAssertions.swift`

## Validation Targets

- Focused: `scripts/scaffold-consumer-adoption.sh --selftest`, `scripts/shell-doctor.sh --selftest`, `swift test --filter OuroAppShellConsumerTestingTests`
- Full shell: `scripts/check-shell-boundary.sh --selftest`, `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`, `scripts/ui-surface-probe.sh`, `scripts/check-coverage.sh`
- Downstream: `scripts/check-downstream-consumers.sh --consumer ouro-md`, `scripts/check-downstream-consumers.sh --consumer ouro-workbench`
