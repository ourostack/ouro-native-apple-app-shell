# Native UI Testing Strategy

Use the narrowest tool that proves the surface contract without overfitting to
SwiftUI internals.

| Surface Type | Default Tool | Use When |
| --- | --- | --- |
| Pure SwiftUI shell components | `shellSurfaceProbe` | The shell owns the view and can render AppKit/SwiftUI headlessly. |
| Consumer app flows | `appHarness` | State setup needs app models, coordinators, or packaged resources. |
| Accessibility affordances | `accessibilityTree` | Labels, menus, or keyboard discoverability are the contract. |
| Rendered copy/layout | `screenshotOCR` | The user-visible text or nonblank rendering must be verified. |
| Test-only view internals | `viewInspector` | A consumer needs in-process SwiftUI body inspection and keeps the dependency test-only. |

Workbench's pinned ViewInspector dependency is valid because it is exact-pinned
and test-target-only. Future consumers should prefer the shell surface probe for
shared shell components and use ViewInspector only when an app view test cannot
be expressed through app harnesses, accessibility, or screenshots.

The visual surface manifest records the selected tool per required shell surface
row so CI can catch accidental coverage drift.
