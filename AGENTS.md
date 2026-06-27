# Agent Notes

This repo is the source of truth for shared native Ouro app-shell behavior.

- Put app identity, release/update policy, About/What's New surfaces, shortcut
  discovery, shared settings chrome, utility-window presentation, and reusable
  AppKit/SwiftUI shell mechanics here first.
- Keep app-specific domain behavior in the consuming app. Use that app's shell
  adapter only for values/actions that connect app state to shell primitives.
- When a consumer needs the same native-app behavior twice, move the primitive
  here before expanding app-local code.
- Run `scripts/check-shell-boundary.sh --selftest`, `swift test -Xswiftc
  -warnings-as-errors -Xswiftc -strict-concurrency=complete`,
  `scripts/ui-surface-probe.sh`, and `scripts/check-coverage.sh` before pushing.
