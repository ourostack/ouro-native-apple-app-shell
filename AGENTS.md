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

## Shipping an app to the App Store

An app built on this package that offers a third-party login (Google, GitHub and so on) shows Sign in with Apple first, full width, before those buttons and any password form, on every platform. App Review rejected Spoonjoy for Mac 1.0 under Guideline 4.8 when it sat last. Follow [App Store submission](https://github.com/ourostack/.github/blob/main/agents/app-store-submission.md) and run `apple-distribution-kit review login-services --root .` in the app's CI ([the kit manual's CI step](https://github.com/ourostack/apple-distribution-kit/blob/main/docs/manual.md#pre-submission-guideline-48-login-services)).
