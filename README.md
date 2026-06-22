# ouro-native-apple-app-shell

Shared native Apple app shell primitives for Ouro apps.

The repository name stays explicit because it is the distribution boundary.
Inside Swift code, the package uses the shorter `OuroAppShell` naming.

## Package Products

- `OuroAppShellCore`: pure, testable app identity, release/update, and
  distribution-channel logic shared by native Ouro apps.

SwiftUI shell surfaces will live in a follow-up product once the core contract is
stable across Ouro MD and Ouro Workbench.
