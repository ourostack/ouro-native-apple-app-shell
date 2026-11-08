<!-- ourostack:brand:start -->
<p align="center">
  <a href="https://github.com/ourostack"><img src="https://raw.githubusercontent.com/ourostack/.github/main/brand/headers/ouro-native-apple-app-shell.webp" alt="Ouro peeking into a glowing pearly seashell by a pond, its inside fitted with tiny lit rooms" width="100%"></a>
</p>
<!-- ourostack:brand:end -->

# Ouro native Apple app shell

**The shared shell of our native Apple apps: app identity, updates, About, settings and command discovery, as one Swift package.** [Ouro MD](https://github.com/ourostack/ouro-md) is built on it.

[Docs index](docs/INDEX.md) · [Shell boundary](docs/shell-boundary.md) · [Adopt it in a new app](docs/INDEX.md#third-app-adoption-quick-start) · [More from Ouro](https://github.com/ourostack)

**Status:** pre-1.0. No tags or releases yet, so consumers track `branch: "main"`.

## Use it

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ourostack/ouro-native-apple-app-shell.git", branch: "main"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "OuroAppShellUI", package: "ouro-native-apple-app-shell"),
    ]),
]

// Your app
import OuroAppShellUI
```

New app? Run `scripts/scaffold-consumer-adoption.sh --output <dir>` from this repo with your app's names and bundle ID. It writes a small package that already passes the shell doctor: the typed shell contract, contract tests, privacy/diagnostics descriptors and `config/ouro-app-control-deck.json`. The [adoption quick start](docs/INDEX.md#third-app-adoption-quick-start) has the full command.

## Package products

Every product is imported by its own name, all starting `OuroAppShell`.


- `OuroAppShellCore`: pure, testable app identity, release/update, and
  distribution-channel logic shared by native Ouro apps.
- `OuroAppShellContract`: typed consumer declarations for app identity,
  shell-first surfaces, release updates, About, command discovery, settings,
  reusable utility windows, and privacy/diagnostics descriptors.
- `OuroAppShellConsumerTesting`: XCTest helpers that let consumer apps enforce
  their shell contract beside their shell adapter.
- `OuroAppShellAppKit`: small macOS runtime helpers for reusable utility-window
  presentation.
- `OuroAppShellUI`: SwiftUI About, What's New, release update, and update
  confirmation / command-reference surfaces that apps drive through value state
  and action closures.

## Validation

Eight checks guard the shell, from strict Swift tests to building the downstream apps against this checkout. The commands and what each proves are in [docs/validation.md](docs/validation.md). The ownership contract is [docs/shell-boundary.md](docs/shell-boundary.md); the map of every doc is [docs/INDEX.md](docs/INDEX.md).
