# Privacy And Diagnostics Contract

Native Ouro apps must expose a user-visible privacy and diagnostics contract.
The shell contract records the minimum disclosure so audits and future apps can
verify the surface without importing app-specific diagnostics collectors.

## Descriptor Fields

`OuroAppShellPrivacyDiagnosticsContract` contains:

| Field | Meaning |
| --- | --- |
| `telemetryConsentEntryPoint` | Menu, settings, or surface path where telemetry consent can be changed or reviewed. |
| `privacyDocumentURL` | Canonical user-readable privacy document. |
| `diagnosticsExportDisclosure` | Plain-language description of what diagnostics export creates. |
| `supportBundleContents` | High-level list of files or evidence categories included in support bundles. |
| `redactionGuarantees` | Content categories that are excluded or redacted by default. |

## Ownership Boundary

The shell owns descriptor shape and validation. Consumers own:

- support bundle collection scripts,
- crash-report collection scope,
- product-specific redaction implementation,
- telemetry event names and payload policy,
- privacy document wording.

This keeps the shell from learning document-editor internals, terminal transcript
storage, or app-specific analytics semantics.
