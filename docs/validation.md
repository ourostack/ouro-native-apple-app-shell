# Validation in depth

The checks that guard the shell, what each proves, and how the shell doctor and consumer scaffold fit in.

## Commands

- `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`
- `scripts/check-shell-boundary.sh --selftest`
- `scripts/check-coverage.sh`
- `scripts/ui-surface-probe.sh`
- `scripts/shell-doctor.sh --selftest`
- `scripts/scaffold-consumer-adoption.sh --selftest`
- `scripts/validate-adoption-docs.py`
- `scripts/check-downstream-consumers.sh`

## What they prove

The UI probe is a package-owned executable that renders representative About,
release update, and installed-confirmation surfaces offscreen. It fails when a
surface loses required rendered text/action labels, renders too little
non-background content, or reports implausible fitting sizes, so shared shell
regressions are caught here before they reach downstream apps.

About keeps its title, release metadata, and action buttons outside the scrolling
release-content viewport. Short histories retain their intrinsic presentation;
long histories remain complete and scroll within the consumer's available height.
The probe covers 25 highlights at 520x520 and the supported 460x360 minimum,
native scroll-area/scrollbar accessibility roles and position values, and
rendered footer buttons and first/last entries before/after scrolling, including
available/failed update states.
Below 400 points tall, compact gaps and padding reserve room for the history
without changing title/button typography; the normal 520x520 presentation is
unchanged for short lists. Non-activating layout tests also cover optional
update controls, preferred fitting size, and histories that already fit.
The visual probe orders an offscreen window key/front: run it on hosted CI when
local foreground-window changes are not permitted.
Direct SwiftUI accessibility-child enumeration in that offscreen harness returns
an empty tree on hosted macOS; these checks do not certify full VoiceOver
navigation or footer accessibility-tree traversal.

The downstream consumer check clones Ouro MD and Ouro Workbench (a labs app, kept as
prior art) into
`.downstream-consumers`, overrides their `ouro-native-apple-app-shell`
SwiftPM dependency to this checkout, then runs each app's build/test/UI smoke.
That catches shell changes that compile locally but break the next consumer
resolution.
CI also reports `scripts/check-downstream-consumers.sh --warn-pins-current` as
an advisory freshness signal. Pin movement alone does not block shell PRs; the
blocking compatibility gates are the pinned downstream smokes, and the scheduled
or manually dispatched `Downstream Live Main` workflow covers latest consumer
refs.
Each downstream command writes a log under `.downstream-consumers/_logs` and is
guarded by `OURO_DOWNSTREAM_STEP_TIMEOUT_SECONDS` (default: 1200 seconds), so a
consumer hang fails loudly with the command log instead of wedging CI.

The shell doctor is the executable adoption checklist for downstream apps. Run
`scripts/shell-doctor.sh --repo /path/to/consumer` to verify that a consumer has
the SwiftPM products, typed shell contract, consumer contract tests, dependency
freshness guard, boundary wrapper, and preflight wiring expected by shared shell
CI. For a new app or generated fixture, add `--strict-adoption` to also require
privacy/diagnostics descriptors and `config/ouro-app-control-deck.json`.

The consumer scaffold is the executable reference shape for a new native app.
Run `scripts/scaffold-consumer-adoption.sh --output /tmp/ouro-shell-fixture
--package-name ExampleConsumer --module-name ExampleApp --app-name "Example"
--bundle-id com.ouro.example --repository ourostack/example --force` to generate
a minimal package that passes the shell doctor and shows exactly where the
consumer contract, tests, shell-boundary wrapper, dependency guard, and preflight
ordering belong.

That generated fixture is the third-app trial path. It depends on the shell
package products `OuroAppShellCore`, `OuroAppShellContract`, and
`OuroAppShellConsumerTesting`; declares identity, release/update policy, About,
command manifest/reference parity, settings, utility windows, and
privacy/diagnostics descriptors; and writes `config/ouro-app-control-deck.json`
as the app-local control deck. A real third app should start from this scaffold,
move the generated contract into its shell adapter, keep app-owned product UI out
of the shell package, and retain the generated preflight ordering until it has an
equivalent CI gate.
