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
                .missingCommandManifest,
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

    func testValidationRejectsCommandManifestDrift() {
        var contract = Self.validContract()
        contract.commandManifest = OuroAppShellCommandSurfaceManifest(commands: [
            .init(id: "global.palette", title: "Command Palette", section: "Global", shortcut: "⌘K"),
            .init(id: "global.palette", title: "Duplicate Palette", section: "Global", shortcut: "⌘K"),
            .init(id: "", title: "", section: "")
        ])

        XCTAssertEqual(
            OuroAppShellContractValidator.validate(contract).map(\.code),
            [
                .emptyCommandID,
                .emptyCommandTitle,
                .emptyCommandSection,
                .duplicateCommandID,
                .commandManifestCountMismatch,
                .commandManifestSectionsMismatch
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
                commandCount: 2,
                sections: ["Global", "Workbench"],
                entryPoint: "Help > Keyboard Shortcuts"
            ),
            commandManifest: OuroAppShellCommandSurfaceManifest(commands: [
                .init(id: "global.palette", title: "Command Palette", section: "Global", shortcut: "⌘K", menuPath: "Ouro Workbench > Commands", commandPaletteTitle: "Command Palette"),
                .init(id: "workbench.new-terminal", title: "New Terminal", section: "Workbench", shortcut: "⌘N", menuPath: "File > New Terminal", commandPaletteTitle: "New Terminal")
            ]),
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
                appOwnedSections: ["Agents", "Terminal"]
            )
        )
    }
}
