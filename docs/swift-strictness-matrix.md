# Swift Strictness Matrix

This matrix records current language mode, target posture, blockers, and the
validation command for each Swift target in the shared shell, Ouro MD, and Ouro
Workbench. It is policy documentation, not a drive-by Swift 6 migration.

## Validation Command

Run:

```sh
scripts/validate-strictness-matrix.py
```

Common compile gates:

- Shell: `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`
- Ouro MD: `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`
- Workbench: `scripts/check-swift-tests.sh` or `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`

| Repo | Target | Current Language Mode | Target Posture | Blockers | Validation Command |
| --- | --- | --- | --- | --- | --- |
| `ouro-native-apple-app-shell` | `OuroAppShellCore` | SwiftPM default from tools 6.0 | Keep warnings-as-errors and strict concurrency complete. | None known. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-native-apple-app-shell` | `OuroAppShellContract` | SwiftPM default from tools 6.0 | Keep warnings-as-errors and strict concurrency complete. | None known. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-native-apple-app-shell` | `OuroAppShellConsumerTesting` | SwiftPM default from tools 6.0 | Keep warnings-as-errors and strict concurrency complete. | None known. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-native-apple-app-shell` | `OuroAppShellAppKit` | SwiftPM default from tools 6.0 | Keep warnings-as-errors and strict concurrency complete. | AppKit main-actor boundaries must stay explicit. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-native-apple-app-shell` | `OuroAppShellUI` | SwiftPM default from tools 6.0 | Keep warnings-as-errors and strict concurrency complete. | SwiftUI/AppKit rendering must stay main-actor safe. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-native-apple-app-shell` | `OuroAppShellUISurfaceProbe` | SwiftPM default from tools 6.0 | Keep warnings-as-errors and strict concurrency complete. | Headless AppKit/Vision availability can block CI environments. | `scripts/ui-surface-probe.sh` |
| `ouro-native-apple-app-shell` | `OuroAppShellCoreTests` | SwiftPM default from tools 6.0 | Keep warnings-as-errors and strict concurrency complete. | None known. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-native-apple-app-shell` | `OuroAppShellContractTests` | SwiftPM default from tools 6.0 | Keep warnings-as-errors and strict concurrency complete. | None known. | `swift test --filter OuroAppShellContractTests -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-native-apple-app-shell` | `OuroAppShellConsumerTestingTests` | SwiftPM default from tools 6.0 | Keep warnings-as-errors and strict concurrency complete. | None known. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-native-apple-app-shell` | `OuroAppShellUITests` | SwiftPM default from tools 6.0 | Keep warnings-as-errors and strict concurrency complete. | SwiftUI rendering APIs must remain main-actor clean. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-md` | `OuroMDCore` | Explicit `.swiftLanguageMode(.v5)` | Remain Swift 5 until a dedicated migration removes blockers. | Existing package pins language mode; do not flip in shell policy work. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-md` | `OuroMD` | Explicit `.swiftLanguageMode(.v5)` | Remain Swift 5 until a dedicated migration removes blockers. | AppKit/WebKit/editor surfaces need a planned Swift 6 audit. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-md` | `OuroMDTests` | Explicit `.swiftLanguageMode(.v5)` | Remain Swift 5 until a dedicated migration removes blockers. | Test target follows app/core mode. | `swift test -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` |
| `ouro-workbench` | `OuroWorkbenchCore` | SwiftPM default from tools 6.0 | Keep strict flags in scripts and tests. | Large local-agent model surface; rely on existing strict test scripts. | `scripts/check-swift-tests.sh` |
| `ouro-workbench` | `OuroWorkbenchShellAdapter` | SwiftPM default from tools 6.0 | Keep strict flags in scripts and tests. | Adapter must stay narrow and not absorb shell behavior. | `scripts/check-swift-tests.sh` |
| `ouro-workbench` | `OuroWorkbenchAppViews` | SwiftPM default from tools 6.0 | Keep strict flags in scripts and tests. | AppKit/SwiftUI view extraction continues in separate lane. | `scripts/check-swift-tests.sh` |
| `ouro-workbench` | `OuroWorkbenchApp` | SwiftPM default from tools 6.0 | Keep strict flags in scripts and tests. | App lifecycle and terminal controller concurrency remain high-risk. | `scripts/check-swift-tests.sh` |
| `ouro-workbench` | `OuroWorkbenchMCP` | SwiftPM default from tools 6.0 | Keep strict flags in scripts and tests. | MCP/server behavior should stay covered by core tests. | `scripts/check-swift-tests.sh` |
| `ouro-workbench` | `OuroWorkbenchScenarioVerifier` | SwiftPM default from tools 6.0 | Keep strict flags in scripts and tests. | Scenario verifier fixtures can drift from app policy. | `scripts/check-swift-tests.sh` |
| `ouro-workbench` | `OuroWorkbenchCoreTests` | SwiftPM default from tools 6.0 | Keep strict flags in scripts and tests. | None known. | `scripts/check-swift-tests.sh` |
| `ouro-workbench` | `OuroWorkbenchAppViewsTests` | SwiftPM default from tools 6.0 | Keep strict flags in scripts and tests; ViewInspector remains test-only. | Snapshot and ViewInspector dependency must not leak into products. | `scripts/check-swift-tests.sh` |
