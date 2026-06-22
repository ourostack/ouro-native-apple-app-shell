# ouro-native-apple-app-shell

Shared native Apple app shell primitives for Ouro apps.

The repository name stays explicit because it is the distribution boundary.
Inside Swift code, the package uses the shorter `OuroAppShell` naming.

## Package Products

- `OuroAppShellCore`: pure, testable app identity, release/update, and
  distribution-channel logic shared by native Ouro apps.
- `OuroAppShellUI`: SwiftUI About, What's New, release update, and update
  confirmation surfaces that apps drive through value state and action closures.
