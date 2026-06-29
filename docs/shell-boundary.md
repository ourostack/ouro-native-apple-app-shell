# Shell Boundary

`ouro-native-apple-app-shell` is the home for native app-shell behavior shared by
Ouro MD, Ouro Workbench, and future native Ouro apps.

## Ownership Map

| Surface | Owner | Rule |
| --- | --- | --- |
| App identity, version, repository, channel | Shell | Apps provide values; shell owns the shape. |
| Release/update checking, labels, prompts, install policy | Shell | Apps may adapt local state, but shared behavior starts here. |
| About / What's New | Shell | Apps provide copy, identity, actions, and domain release notes. |
| Keyboard shortcut / command discovery | Shell | Apps provide command rows; shell owns the reference surface. |
| Settings chrome | Adapter | Shared settings sections should move shellward; domain settings stay app-owned. |
| Utility windows and reusable AppKit presentation | Shell | Apps provide content; shell owns the window presenter. |
| Telemetry consent and common event envelope | Adapter | Consent/common shape should be shared; event meaning is app-owned. |
| Primary content and editing | App | Product-specific behavior stays in the consuming app. |
| Domain workflows | App | Product-specific workflows stay in the consuming app. |

## Consumer Contract Kit

`OuroAppShellContract` is the shared declaration surface for native app-shell
adoption. Consuming apps declare identity, required shell-first surfaces, and
the app-provided descriptors for release updates, About, command reference,
utility windows, and settings.

`OuroAppShellConsumerTesting` is the XCTest helper product. Consumers should add
a small contract test beside their shell adapter so CI fails when an app adds a
shared shell surface locally without declaring or validating it.

`scripts/shell-doctor.sh` is the executable adoption checklist. It checks a
consumer checkout for the shell dependency/products, typed contract declaration,
contract assertion tests, dependency freshness script, boundary wrapper,
preflight wiring, and the boundary scan itself. Run it from this repo with:

```bash
scripts/shell-doctor.sh --repo /path/to/ouro-md
scripts/shell-doctor.sh --repo /path/to/ouro-workbench
```

`scripts/scaffold-consumer-adoption.sh` is the executable starting point for a
new consumer. It generates a tiny Swift package fixture with the Package.swift
dependency, `OuroAppShellContract` declaration, `OuroAppShellConsumerTesting`
test, dependency guard, boundary wrapper, allowlist file, and preflight ordering
that the doctor expects. Start there when adding another native Ouro app, then
port the generated shape into the real app's shell adapter.

Shell CI also runs the doctor inside `scripts/check-downstream-consumers.sh`
after overriding each consumer to the local shell checkout, so a shell PR cannot
silently drift away from the current consumer adoption shape.

## Adapter Rule

Each consuming app should have exactly one obvious shell adapter module. New
native-app behavior goes through this decision flow:

1. Is it primary product content or domain workflow behavior? Keep it in the app.
2. Is it app identity, About, updates, shortcuts, settings chrome, utility
   windows, or lifecycle chrome? Start in this shell repo.
3. Does it need app-specific values or actions? Put only that glue in the
   app's shell adapter.
4. If the adapter starts containing generic behavior, move that behavior back
   into the shell package.

## CI Contract

The shell owns a boundary scanner. Consumers should run a local wrapper around
`scripts/check-shell-boundary.sh` so new app-local shell behavior trips CI with a
direct instruction instead of relying on reviewer memory.

Downstream pins move in two phases. Shell changes first stay compatible with the
existing pinned app commits. Contract files in consumers should contain typed
`OuroAppShellContract` declarations, not shell-owned UI implementations. After
each consumer adopts the contract helper on main, this repo refreshes
`scripts/downstream-consumers.contract.tsv` to those consumer commits so shell CI
proves the declared contract path, not only build compatibility.
CI also reports `scripts/check-downstream-consumers.sh --check-pins-current` as
an advisory freshness signal. A listed live ref moving is not itself a shell
compatibility failure; pinned downstream smokes remain blocking on PRs, and the
scheduled/manual `Downstream Live Main` workflow tests this shell against latest
consumer refs.
