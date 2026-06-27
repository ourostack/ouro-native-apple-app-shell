# ouro-native-apple-app-shell

Shared native Apple app shell primitives for Ouro apps.

The repository name stays explicit because it is the distribution boundary.
Inside Swift code, the package uses the shorter `OuroAppShell` naming.

## Package Products

- `OuroAppShellCore`: pure, testable app identity, release/update, and
  distribution-channel logic shared by native Ouro apps.
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

See [docs/shell-boundary.md](docs/shell-boundary.md) for the ownership contract
used by consumers and CI.
