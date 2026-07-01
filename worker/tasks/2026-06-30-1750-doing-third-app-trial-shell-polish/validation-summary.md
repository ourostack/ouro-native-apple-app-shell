# Validation Summary

## Red Phases

- Unit 1a: `scripts/scaffold-consumer-adoption.sh --selftest` failed before implementation with `fixture contract must declare privacy diagnostics`.
- Unit 2a: `scripts/validate-adoption-docs.py` failed before docs updates with missing README/control-deck/privacy quick-start guidance.
- Unit 3 first downstream run: `scripts/check-downstream-consumers.sh --consumer ouro-md` and `--consumer ouro-workbench` failed because `shell-doctor` initially required strict third-app privacy/control-deck adoption for existing pinned consumers. Fixed by making strict adoption opt-in and using it for scaffold/new-app validation.

## Passing Local Shell Gates

- `scripts/check-shell-boundary.sh --selftest`: pass.
- `scripts/validate-adoption-docs.py`: pass.
- `scripts/shell-doctor.sh --selftest`: pass with strict adoption enabled inside selftest.
- `scripts/scaffold-consumer-adoption.sh --selftest`: pass; generated fixture compiles/tests and includes privacy diagnostics plus `config/ouro-app-control-deck.json`.
- `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`: pass, 83 tests.
- `scripts/ui-surface-probe.sh`: pass.
- `scripts/check-coverage.sh`: pass; shell core, contract kit, consumer testing, and UI contracts report 100% line+region coverage; rendered SwiftUI surfaces remain covered by the UI probe.

## Passing Downstream Gates

Both downstream checks were run with disposable `OURO_DOWNSTREAM_WORK_ROOT` and `OURO_DOWNSTREAM_LOG_DIR` temp directories.

- `scripts/check-downstream-consumers.sh --consumer ouro-md`: pass after strict-adoption compatibility fix; Ouro MD build and UI surface smoke pass.
- `scripts/check-downstream-consumers.sh --consumer ouro-workbench`: pass after strict-adoption compatibility fix; Workbench test suite passed with 4,476 tests, 1 skipped, 0 failures.

## Noise Check

- Generated fixture inspection showed only the expected files: `Package.swift`, README, contract source/test, `config/ouro-app-control-deck.json`, and scripts.
- `git status --short --ignored` showed only ignored `.build/` generated state after validation.
