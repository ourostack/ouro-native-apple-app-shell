# Shared Settings And Telemetry Roadmap

The shell owns the common settings chrome contract for native Ouro apps. Consumers
still own domain preferences and concrete telemetry event names.

## Shared Settings Sections

Every native consumer that declares `.settings` should map common app-shell
settings into `OuroAppShellSettingsContract.sharedSections`:

| Kind | Required Meaning | Consumer-Owned Details |
| --- | --- | --- |
| `updates` | Where users review release/update policy and channel state. | Installer capability, staged update actions, app copy. |
| `telemetry` | Where users find telemetry consent controls. | Event names, payload values, analytics provider wiring. |
| `privacy` | Where users find privacy disclosure. | App-specific privacy document copy. |
| `about` | Where users can reach app identity/about. | App subtitle, repository URL, release copy. |
| `keyboardShortcuts` | Where users can reach command reference. | App command catalog and section order. |

`appOwnedSections` stays available for app preferences such as editor behavior,
terminal behavior, boss behavior, themes, and other domain settings.

## Telemetry Boundary

The shell contract describes the consent entry point and common disclosure shape.
It does not define event names, event payload keys, analytics vendors, user
identity storage, or event transport. Consumers must document:

- how telemetry can be enabled or disabled,
- what coarse categories may be sent,
- what content is never sent,
- whether local development builds send telemetry,
- how anonymous install identifiers can be reset when applicable.

## Adoption Steps

1. Declare shared settings sections in each consumer contract.
2. Declare a privacy/diagnostics descriptor in each consumer contract.
3. Keep app-specific settings controls in the app adapter or app views.
4. Use shell contract tests to prevent blank entry points or empty disclosure
   rows from reaching downstream apps.
