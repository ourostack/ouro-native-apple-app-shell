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
| Document editing, rendering, files | App | Ouro MD domain logic. |
| Agent/session orchestration | App | Workbench domain logic. |

## Adapter Rule

Each consuming app should have exactly one obvious shell adapter module. New
native-app behavior goes through this decision flow:

1. Is it document/editor or Workbench domain behavior? Keep it in the app.
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
