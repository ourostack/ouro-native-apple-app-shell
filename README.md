# ouro-native-apple-app-shell

Shared native Apple app shell primitives for Ouro apps.

The repository name stays explicit because it is the distribution boundary.
Inside Swift code, the package uses the shorter `OuroAppShell` naming.

## Package Products

- `OuroAppShellCore`: pure, testable app identity, release/update, and
  distribution-channel logic shared by native Ouro apps.
- `OuroAppShellUI`: SwiftUI About, What's New, release update, and update
  confirmation surfaces that apps drive through value state and action closures.

## Validation

- `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`
- `scripts/check-coverage.sh`
- `scripts/ui-surface-probe.sh`

The UI probe is a package-owned executable that renders representative About,
release update, and installed-confirmation surfaces offscreen. It fails when a
surface loses required semantic tokens/action labels, renders too little
non-background content, or reports implausible fitting sizes, so shared shell
regressions are caught here before they reach downstream apps.
