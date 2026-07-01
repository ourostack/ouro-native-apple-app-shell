# Planning: Third-App Trial And Shell Package Polish

**Status**: drafting
**Created**: 2026-06-30 17:50

## Goal
Prove that a third native Ouro app can adopt `ouro-native-apple-app-shell` without repo-memory by using a tiny generated consumer fixture, then polish the shell package docs and validation so the adoption path is obvious and CI-enforced.

## Upstream Work Items
- `/Users/arimendelow/desk/ouro-md/native-app-shell-next-roadmap/task.md` R1: Third-App Trial
- `/Users/arimendelow/desk/ouro-md/native-app-shell-next-roadmap/task.md` R2: Shell Package Polish

**DO NOT include time estimates (hours/days) — planning should focus on scope and criteria, not duration.**

## Scope

### In Scope
- Strengthen the in-repo consumer scaffold so it exercises package products, `OuroAppShellContract`, command manifest/reference parity, release/update policy, settings, privacy/diagnostics descriptors, utility windows, shell boundary wrapper, dependency guard, and preflight ordering.
- Add or update executable checks so the generated third-app fixture can be validated from the shell repo without creating a real GitHub repository.
- Polish README/docs/control-deck guidance so a future native Ouro app starts from one obvious path and understands which shell package products to adopt.
- Validate the shell repo and relevant downstream consumers (`ouro-md`, `ouro-workbench`) against the updated adoption contract.

### Out of Scope
- Creating a real new GitHub repository for the third app.
- Paid Apple Developer signing, notarization, TestFlight, App Store, or production release-channel operations.
- Production-grade third-app UI.
- Broad Ouro MD or Ouro Workbench refactors beyond validation and compatibility fixes directly required by this shell change.

## Completion Criteria
- [ ] A generated third-app fixture exercises shell contract descriptors for package products, identity, release/update policy, About, command manifest/reference parity, settings, utility windows, privacy/diagnostics, dependency guard, boundary wrapper, and preflight ordering.
- [ ] The scaffold selftest and shell doctor validate that fixture without relying on repo-memory or a real third GitHub repo.
- [ ] README/docs/control-deck guidance describes the adoption path and validation commands from a cold start.
- [ ] Shell validation passes: `scripts/check-shell-boundary.sh --selftest`, `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`, `scripts/ui-surface-probe.sh`, and `scripts/check-coverage.sh`.
- [ ] Relevant downstream checks pass for `ouro-md` and `ouro-workbench` or any residual blocker is classified as a true hard exception with evidence.
- [ ] 100% test coverage on all new code
- [ ] All tests pass
- [ ] No warnings

## Code Coverage Requirements
**MANDATORY: 100% coverage on all new code.**
- No `[ExcludeFromCodeCoverage]` or equivalent on new code
- All branches covered (if/else, switch, try/catch)
- All error paths tested
- Edge cases: null, empty, boundary values

## Open Questions
- [ ] None requiring human direction under the autopilot mandate. Any adoption-shape ambiguity will go through reviewer gates.

## Decisions Made
- Use the existing `scripts/scaffold-consumer-adoption.sh` as the third-app trial path instead of creating a real repository, because it already generates a disposable SwiftPM consumer and can be made to prove the adoption contract locally.
- Keep durable task docs in `worker/tasks/` because the branch is `worker/third-app-trial-shell-polish` and the active repo instructions do not define a narrower task-doc directory.
- Treat human approval gates from the default project instructions as disabled by the explicit autopilot mandate; reviewer gates remain required.

## Context / References
- `/Users/arimendelow/Projects/ouro-native-apple-app-shell-worker-third-app/README.md`
- `/Users/arimendelow/Projects/ouro-native-apple-app-shell-worker-third-app/docs/INDEX.md`
- `/Users/arimendelow/Projects/ouro-native-apple-app-shell-worker-third-app/docs/shell-boundary.md`
- `/Users/arimendelow/Projects/ouro-native-apple-app-shell-worker-third-app/docs/privacy-diagnostics-contract.md`
- `/Users/arimendelow/Projects/ouro-native-apple-app-shell-worker-third-app/scripts/scaffold-consumer-adoption.sh`
- `/Users/arimendelow/Projects/ouro-native-apple-app-shell-worker-third-app/scripts/shell-doctor.sh`
- `/Users/arimendelow/Projects/ouro-native-apple-app-shell-worker-third-app/scripts/check-downstream-consumers.sh`
- `/Users/arimendelow/Projects/ouro-native-apple-app-shell-worker-third-app/scripts/downstream-consumers.json`
- `/Users/arimendelow/Projects/ouro-native-apple-app-shell-worker-third-app/Sources/OuroAppShellContract/OuroAppShellContract.swift`
- `/Users/arimendelow/Projects/ouro-native-apple-app-shell-worker-third-app/Sources/OuroAppShellConsumerTesting/OuroAppShellContractAssertions.swift`

## Notes
Tinfoil Hat pass: the current scaffold validates command manifests but does not exercise privacy/diagnostics descriptors or an explicit control-deck artifact, so a third app could still miss those adoption surfaces. The validation path must prove the generated fixture itself, not just existing MD/Workbench consumers.

## Progress Log
- 2026-06-30 17:50 Created
