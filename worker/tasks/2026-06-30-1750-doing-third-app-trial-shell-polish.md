# Doing: Third-App Trial And Shell Package Polish

**Status**: READY_FOR_EXECUTION
**Execution Mode**: direct
**Created**: 2026-06-30 17:50
**Planning**: ./2026-06-30-1750-planning-third-app-trial-shell-polish.md
**Artifacts**: ./2026-06-30-1750-doing-third-app-trial-shell-polish/

## Execution Mode

- **pending**: Awaiting user approval before each unit starts (non-autopilot interactive mode only; autopilot must convert this to `spawn` or `direct` unless a hard exception is present)
- **spawn**: Spawn sub-agent for each unit (parallel/autonomous)
- **direct**: Execute units sequentially in current session (default)

## Objective
Prove that a third native Ouro app can adopt `ouro-native-apple-app-shell` without repo-memory by using a tiny generated consumer fixture, then polish the shell package docs and validation so the adoption path is obvious and CI-enforced.

## Upstream Work Items
- `/Users/arimendelow/desk/ouro-md/native-app-shell-next-roadmap/task.md` R1: Third-App Trial
- `/Users/arimendelow/desk/ouro-md/native-app-shell-next-roadmap/task.md` R2: Shell Package Polish

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

## TDD Requirements
**Strict TDD — no exceptions:**
1. **Tests first**: Write failing tests BEFORE any implementation
2. **Verify failure**: Run tests, confirm they FAIL (red)
3. **Minimal implementation**: Write just enough code to pass
4. **Verify pass**: Run tests, confirm they PASS (green)
5. **Refactor**: Clean up, keep tests green
6. **No skipping**: Never write implementation without failing test first

## Work Units

### Legend
⬜ Not started · 🔄 In progress · ✅ Done · ❌ Blocked

**CRITICAL: Every unit header MUST start with status emoji (⬜ for new units).**

### ✅ Unit 0: Setup/Research
**What**: Capture current scaffold, shell-doctor, docs, package, and downstream validation shape; create artifacts directory.
**Output**: Notes in `./2026-06-30-1750-doing-third-app-trial-shell-polish/`.
**Acceptance**: Current commands and source targets are known before edits.

### ✅ Unit 1a: Third-App Scaffold Contract — Tests
**What**: Add failing selftest assertions to `scripts/scaffold-consumer-adoption.sh` and/or `scripts/shell-doctor.sh` proving the generated fixture includes privacy/diagnostics descriptors and an app-local control deck artifact.
**Output**: Test/script changes only.
**Acceptance**: `scripts/scaffold-consumer-adoption.sh --selftest` fails for missing descriptor/control-deck coverage before implementation.

### ✅ Unit 1b: Third-App Scaffold Contract — Implementation
**What**: Update `scripts/scaffold-consumer-adoption.sh` to generate privacy/diagnostics descriptors and a minimal `config/ouro-app-control-deck.json`; update shell-doctor static checks if needed so generated fixtures are validated by the executable adoption checklist.
**Output**: Scaffold/doctor implementation.
**Acceptance**: `scripts/scaffold-consumer-adoption.sh --selftest` passes and generated fixture contents prove the new descriptors/artifact.

### ✅ Unit 1c: Third-App Scaffold Contract — Coverage & Refactor
**What**: Run shell script selftests and focused Swift tests for contract validation helpers; refactor only if needed.
**Output**: Passing focused validation evidence in artifacts.
**Acceptance**: Scaffold selftest, shell-doctor selftest, and `swift test --filter OuroAppShellConsumerTestingTests` pass with no warnings.

### ⬜ Unit 2a: Adoption Docs And Control Deck — Tests
**What**: Add failing doc/metadata assertions to existing selftests or lightweight script checks proving README/docs mention the cold-start scaffold path, privacy/diagnostics, control deck, and package products needed by a third app.
**Output**: Test/script assertions only.
**Acceptance**: The chosen validation fails before docs are updated.

### ⬜ Unit 2b: Adoption Docs And Control Deck — Implementation
**What**: Update README, `docs/INDEX.md`, `docs/shell-boundary.md`, and any relevant control-deck guidance so the third-app adoption path is explicit and consistent with the generated fixture.
**Output**: Documentation/control-deck polish.
**Acceptance**: The doc validation from Unit 2a passes.

### ⬜ Unit 2c: Adoption Docs And Control Deck — Coverage & Refactor
**What**: Run docs/scaffold/doctor validation again and inspect generated fixture output for stale wording or generated Packages noise.
**Output**: Passing validation logs in artifacts.
**Acceptance**: Docs validation passes, generated fixture remains disposable, and no generated package cache noise is tracked.

### ⬜ Unit 3: Full Shell And Downstream Validation
**What**: Run required shell validation plus downstream checks for `ouro-md` and `ouro-workbench`.
**Output**: Logs in artifacts.
**Acceptance**: `scripts/check-shell-boundary.sh --selftest`, `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`, `scripts/ui-surface-probe.sh`, `scripts/check-coverage.sh`, and `scripts/check-downstream-consumers.sh --consumer ouro-md/--consumer ouro-workbench` pass or any residual is classified with hard-exception evidence.

### ⬜ Unit 4: Final Review, PR, Merge, Cleanup
**What**: Run final self-review/reviewer gate, push branch, open PR, wait for CI, merge, verify main, and remove the dedicated worktree/branch if terminal.
**Output**: Merged PR and cleanup evidence.
**Acceptance**: PR merged to `main`, CI green or non-applicable with evidence, local validation recorded, no stale worktree/branch from this run remains, no generated `Packages` noise is tracked.

## Execution
- **TDD strictly enforced**: tests → red → implement → green → refactor
- Commit after each phase (1a, 1b, 1c)
- Push after each unit complete
- Run full test suite before marking unit done
- **All artifacts**: Save outputs, logs, data to `./2026-06-30-1750-doing-third-app-trial-shell-polish/` directory
- **Fixes/blockers**: Spawn sub-agent immediately — don't ask, just do it
- **Decisions made**: Update docs immediately, commit right away

## Progress Log
- 2026-06-30 17:50 Created from planning doc
- 2026-06-30 17:50 Unit 0 complete: captured scaffold, doctor, docs, control-deck, and validation terrain before edits.
- 2026-06-30 17:50 Unit 1a complete: added red scaffold/doctor assertions for privacy diagnostics and control-deck fixture coverage; red log shows missing privacy diagnostics.
- 2026-06-30 18:00 Unit 1b complete: scaffold now generates privacy/diagnostics descriptors and `config/ouro-app-control-deck.json`; scaffold selftest passes.
- 2026-06-30 18:02 Unit 1c complete: scaffold selftest, shell-doctor selftest, and focused consumer testing Swift tests pass with strict flags.
