import Foundation
import XCTest
@testable import OuroAppShellContract

final class OuroAppShellContractTests: XCTestCase {
    func testValidContractDeclaresSharedShellSurfaces() {
        let contract = Self.validContract()

        XCTAssertEqual(
            contract.shellFirstRequiredSurfaces,
            [.appIdentity, .releaseUpdates, .about, .keyboardShortcuts, .windowChrome, .settings]
        )
        XCTAssertTrue(OuroAppShellContractValidator.validate(contract).isEmpty)
    }

    func testValidationRequiresDescriptorsForRequiredShellSurfaces() {
        let contract = OuroAppShellContract(
            identity: AppShellIdentity(
                appName: "Ouro MD",
                bundleIdentifier: "org.ourostack.ouro-md",
                repository: "ourostack/ouro-md",
                version: "0.9.54"
            ),
            requiredSurfaces: [.appIdentity, .releaseUpdates, .about, .keyboardShortcuts, .windowChrome, .settings]
        )

        XCTAssertEqual(
            OuroAppShellContractValidator.validate(contract).map(\.code),
            [
                .missingReleaseUpdates,
                .missingAbout,
                .missingCommandReference,
                .missingUtilityWindows,
                .missingSettings
            ]
        )
    }

    func testValidationRejectsAppOwnedAndDuplicateRequiredSurfaces() {
        let contract = OuroAppShellContract(
            identity: AppShellIdentity(
                appName: "",
                bundleIdentifier: "",
                repository: "",
                version: ""
            ),
            requiredSurfaces: [.appIdentity, .primaryContent, .appIdentity],
            commandReference: OuroAppShellCommandReferenceContract(title: "", commandCount: 0, sections: [], entryPoint: "")
        )

        XCTAssertEqual(
            OuroAppShellContractValidator.validate(contract).map(\.code),
            [
                .emptyIdentityField,
                .duplicateRequiredSurface,
                .appOwnedSurfaceRequired,
                .emptyCommandReferenceTitle,
                .emptyCommandReference,
                .emptyCommandReferenceSections,
                .emptyCommandReferenceEntryPoint
            ]
        )
    }

    func testValidationRejectsInvalidOptionalDescriptors() {
        let contract = OuroAppShellContract(
            identity: AppShellIdentity(
                appName: "Ouro MD",
                bundleIdentifier: "org.ourostack.ouro-md",
                repository: "ourostack/ouro-md",
                version: "0.9.54"
            ),
            requiredSurfaces: [],
            releaseUpdates: OuroAppShellReleaseUpdateContract(
                policy: ReleaseUpdatePolicy(
                    assetNamingPolicy: ReleaseAssetNamingPolicy(archiveSuffix: "", manifestSuffix: "")
                ),
                supportsInstallAndRelaunch: false,
                supportsReleasePage: false
            ),
            about: OuroAppShellAboutContract(subtitle: " "),
            utilityWindows: [
                OuroAppShellUtilityWindowContract(id: "", surface: .primaryContent, title: "")
            ],
            settings: OuroAppShellSettingsContract(entryPoint: "")
        )

        XCTAssertEqual(
            OuroAppShellContractValidator.validate(contract).map(\.code),
            [
                .emptyReleasePolicy,
                .emptyAboutSubtitle,
                .emptyUtilityWindowID,
                .appOwnedUtilityWindowSurface,
                .emptyUtilityWindowTitle,
                .emptySettingsEntryPoint
            ]
        )
    }

    func testSettingsContractDeclaresSharedSections() {
        let settings = OuroAppShellSettingsContract(
            entryPoint: "Ouro Workbench > Settings",
            sharedSections: [
                .updates(entryPoint: "Settings > Software Updates"),
                .telemetry(entryPoint: "Settings > Privacy"),
                .privacy(entryPoint: "Settings > Privacy"),
                .about(entryPoint: "Help > About Ouro Workbench"),
                .keyboardShortcuts(entryPoint: "Ouro Workbench > Keyboard Shortcuts")
            ],
            appOwnedSections: ["Terminal", "Boss"]
        )

        XCTAssertEqual(settings.sharedSections.map(\.kind), [.updates, .telemetry, .privacy, .about, .keyboardShortcuts])
        XCTAssertEqual(settings.appOwnedSections, ["Terminal", "Boss"])
    }

    func testValidationRejectsMalformedSettingsSectionsAndDiagnostics() {
        let contract = OuroAppShellContract(
            identity: AppShellIdentity(
                appName: "Ouro Workbench",
                bundleIdentifier: "com.ourostack.workbench",
                repository: "ourostack/ouro-workbench",
                version: "0.1.186"
            ),
            requiredSurfaces: [],
            settings: OuroAppShellSettingsContract(
                entryPoint: "Ouro Workbench > Settings",
                sharedSections: [
                    OuroAppShellSettingsSectionContract(kind: .updates, entryPoint: " ")
                ],
                appOwnedSections: [" "]
            ),
            privacyDiagnostics: OuroAppShellPrivacyDiagnosticsContract(
                telemetryConsentEntryPoint: " ",
                privacyDocumentURL: URL(string: "https://ouroboros.bot/privacy")!,
                diagnosticsExportDisclosure: " ",
                supportBundleContents: ["runtime.txt", " "],
                redactionGuarantees: ["no transcript contents", " "]
            )
        )

        XCTAssertEqual(
            OuroAppShellContractValidator.validate(contract).map(\.code),
            [
                .emptySharedSettingsSectionEntryPoint,
                .emptyAppOwnedSettingsSection,
                .emptyTelemetryConsentEntryPoint,
                .emptyDiagnosticsExportDisclosure,
                .emptySupportBundleContent,
                .emptyRedactionGuarantee
            ]
        )
    }

    func testContractIsCodable() throws {
        let contract = Self.validContract()

        let encoded = try JSONEncoder().encode(contract)
        let decoded = try JSONDecoder().decode(OuroAppShellContract.self, from: encoded)

        XCTAssertEqual(decoded, contract)
    }

    private static func validContract() -> OuroAppShellContract {
        OuroAppShellContract(
            identity: AppShellIdentity(
                appName: "Ouro Workbench",
                bundleIdentifier: "com.ourostack.workbench",
                repository: "ourostack/ouro-workbench",
                version: "0.1.186",
                distributionChannel: .directDownload
            ),
            requiredSurfaces: [.appIdentity, .releaseUpdates, .about, .keyboardShortcuts, .windowChrome, .settings],
            releaseUpdates: OuroAppShellReleaseUpdateContract(
                policy: .buildMatchedPrerelease(namePrefix: "OuroWorkbench-"),
                supportsInstallAndRelaunch: true,
                supportsReleasePage: true
            ),
            about: OuroAppShellAboutContract(
                subtitle: "Native workbench for Ouro agents",
                repositoryURL: URL(string: "https://github.com/ourostack/ouro-workbench")!
            ),
            commandReference: OuroAppShellCommandReferenceContract(
                title: "Keyboard Shortcuts",
                commandCount: 18,
                sections: ["Global", "Workbench"],
                entryPoint: "Help > Keyboard Shortcuts"
            ),
            utilityWindows: [
                OuroAppShellUtilityWindowContract(
                    id: "keyboard-shortcuts",
                    surface: .keyboardShortcuts,
                    title: "Keyboard Shortcuts"
                ),
                OuroAppShellUtilityWindowContract(
                    id: "about",
                    surface: .about,
                    title: "About Ouro Workbench"
                )
            ],
            settings: OuroAppShellSettingsContract(
                entryPoint: "Ouro Workbench > Settings",
                sharedSections: [
                    .updates(entryPoint: "Settings > Software Updates"),
                    .telemetry(entryPoint: "Settings > Privacy"),
                    .privacy(entryPoint: "Settings > Privacy"),
                    .about(entryPoint: "Help > About Ouro Workbench"),
                    .keyboardShortcuts(entryPoint: "Ouro Workbench > Keyboard Shortcuts")
                ],
                appOwnedSections: ["Agents", "Terminal"]
            ),
            privacyDiagnostics: OuroAppShellPrivacyDiagnosticsContract(
                telemetryConsentEntryPoint: "Settings > Privacy",
                privacyDocumentURL: URL(string: "https://github.com/ourostack/ouro-workbench/blob/main/README.md#support-diagnostics")!,
                diagnosticsExportDisclosure: "Support Diagnostics creates a local zip with runtime evidence.",
                supportBundleContents: ["system.txt", "app-bundle.txt", "runtime.txt", "workspace-summary.txt"],
                redactionGuarantees: ["no transcript contents by default", "no raw workspace state by default"]
            )
        )
    }
}
