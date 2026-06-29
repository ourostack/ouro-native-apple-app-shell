# ouro-native-apple-app-shell

Shared native Apple app shell primitives for Ouro apps.

The repository name stays explicit because it is the distribution boundary.
Inside Swift code, the package uses the shorter `OuroAppShell` naming.

## Package Products

- `OuroAppShellCore`: pure, testable app identity, release/update, and
  distribution-channel logic shared by native Ouro apps.
- `OuroAppShellContract`: typed consumer declarations for app identity,
  shell-first surfaces, release updates, About, command discovery, settings, and
  reusable utility windows.
- `OuroAppShellConsumerTesting`: XCTest helpers that let consumer apps enforce
  their shell contract beside their shell adapter.
- `OuroAppShellAppKit`: small macOS runtime helpers for reusable utility-window
  presentation.
- `OuroAppShellUI`: SwiftUI About, What's New, release update, and update
  confirmation / command-reference surfaces that apps drive through value state
  and action closures.

## Validation

- `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`
- `scripts/check-shell-boundary.sh --selftest`
- `scripts/check-coverage.sh`
- `scripts/ui-surface-probe.sh`
- `scripts/shell-doctor.sh --selftest`
- `scripts/scaffold-consumer-adoption.sh --selftest`
- `scripts/check-downstream-consumers.sh`

The UI probe is a package-owned executable that renders representative About,
release update, and installed-confirmation surfaces offscreen. It fails when a
surface loses required rendered text/action labels, renders too little
non-background content, or reports implausible fitting sizes, so shared shell
regressions are caught here before they reach downstream apps.

The downstream consumer check clones Ouro MD and Ouro Workbench into
`.downstream-consumers`, overrides their `ouro-native-apple-app-shell`
SwiftPM dependency to this checkout, then runs each app's build/test/UI smoke.
That catches shell changes that compile locally but break the next consumer
resolution.
CI also reports `scripts/check-downstream-consumers.sh --check-pins-current` as
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
CI.

The consumer scaffold is the executable reference shape for a new native app.
Run `scripts/scaffold-consumer-adoption.sh --output /tmp/ouro-shell-fixture
--package-name ExampleConsumer --module-name ExampleApp --app-name "Example"
--bundle-id com.ouro.example --repository ourostack/example --force` to generate
a minimal package that passes the shell doctor and shows exactly where the
consumer contract, tests, shell-boundary wrapper, dependency guard, and preflight
ordering belong.

See [docs/shell-boundary.md](docs/shell-boundary.md) for the ownership contract
used by consumers and CI.
