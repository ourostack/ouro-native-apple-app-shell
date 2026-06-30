import Foundation
import XCTest
@testable import OuroAppShellConsumerTesting

final class OuroAppShellContractAssertionsTests: XCTestCase {
    func testExecutableLocalAdapterFixtureUsesHelper() {
        let contract = Self.ouroMDStyleContract()

        OuroAppShellContractAssertions.assertRequiresShellFirstSurfaces(
            contract,
            [.appIdentity, .releaseUpdates, .about, .keyboardShortcuts, .windowChrome, .settings]
        )
        OuroAppShellContractAssertions.assertValid(contract)
        OuroAppShellContractAssertions.assertCommandManifestMatchesReference(contract)
        OuroAppShellContractAssertions.assertCommandManifest(
            contract,
            matches: contract.commandManifest?.commands ?? []
        )
    }

    func testAdapterLibraryFixtureUsesHelper() {
        let contract = Self.workbenchStyleContract()

        OuroAppShellContractAssertions.assertRequiresShellFirstSurfaces(
            contract,
            [.appIdentity, .releaseUpdates, .about, .keyboardShortcuts, .windowChrome, .settings]
        )
        OuroAppShellContractAssertions.assertValid(contract)
        OuroAppShellContractAssertions.assertCommandManifestMatchesReference(contract)
    }

    func testMessageFormatsIssuesForConsumerFailures() {
        let issue = OuroAppShellContractIssue(
            code: .missingAbout,
            message: "About requires an about contract.",
            surface: .about
        )
        let identityIssue = OuroAppShellContractIssue(
            code: .emptyIdentityField,
            message: "Identity fields must not be empty."
        )

        XCTAssertEqual(
            OuroAppShellContractAssertions.message(for: [issue]),
            "missingAbout(about): About requires an about contract."
        )
        XCTAssertEqual(
            OuroAppShellContractAssertions.message(for: [identityIssue]),
            "emptyIdentityField: Identity fields must not be empty."
        )
        XCTAssertEqual(
            OuroAppShellContractAssertions.message(for: []),
            "Ouro app shell contract is valid."
        )
    }

    func testAssertValidSurfacesConsumerContractFailures() {
        let contract = OuroAppShellContract(
            identity: AppShellIdentity(
                appName: "",
                bundleIdentifier: "",
                repository: "",
                version: ""
            ),
            requiredSurfaces: [.about]
        )

        XCTExpectFailure("invalid consumer contracts should fail the assertion helper", strict: true) {
            OuroAppShellContractAssertions.assertValid(contract)
        }
    }

    private static func ouroMDStyleContract() -> OuroAppShellContract {
        OuroAppShellContract(
            identity: AppShellIdentity(
                appName: "Ouro MD",
                bundleIdentifier: "org.ourostack.ouro-md",
                repository: "ourostack/ouro-md",
                version: "0.9.54"
            ),
            requiredSurfaces: [.appIdentity, .releaseUpdates, .about, .keyboardShortcuts, .windowChrome, .settings],
            releaseUpdates: OuroAppShellReleaseUpdateContract(
                policy: .stable(assetNamingPolicy: .versionedArchiveAndManifest(namePrefix: "Ouro-MD-")),
                supportsInstallAndRelaunch: true,
                supportsReleasePage: true
            ),
            about: OuroAppShellAboutContract(
                subtitle: "Markdown editor",
                repositoryURL: URL(string: "https://github.com/ourostack/ouro-md")!
            ),
            commandReference: OuroAppShellCommandReferenceContract(
                title: "Keyboard Shortcuts",
                commandCount: 2,
                sections: ["File", "Editing"],
                entryPoint: "Help > Keyboard Shortcuts"
            ),
            commandManifest: OuroAppShellCommandSurfaceManifest(commands: [
                .init(id: "file.new", title: "New Document", section: "File", shortcut: "⌘N", menuPath: "File > New"),
                .init(id: "edit.find", title: "Find", section: "Editing", shortcut: "⌘F", menuPath: "Edit > Find > Find")
            ]),
            utilityWindows: [
                OuroAppShellUtilityWindowContract(id: "about", surface: .about, title: "About Ouro MD")
            ],
            settings: OuroAppShellSettingsContract(
                entryPoint: "Ouro MD > Settings",
                appOwnedSections: ["Editor", "Files"]
            )
        )
    }

    private static func workbenchStyleContract() -> OuroAppShellContract {
        OuroAppShellContract(
            identity: AppShellIdentity(
                appName: "Ouro Workbench",
                bundleIdentifier: "com.ourostack.workbench",
                repository: "ourostack/ouro-workbench",
                version: "0.1.186"
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
                .init(id: "global.palette", title: "Command Palette", section: "Global", shortcut: "⌘K", menuPath: "Ouro Workbench > Commands"),
                .init(id: "workbench.new-terminal", title: "New Terminal", section: "Workbench", shortcut: "⌘N", menuPath: "File > New Terminal")
            ]),
            utilityWindows: [
                OuroAppShellUtilityWindowContract(id: "shortcuts", surface: .keyboardShortcuts, title: "Keyboard Shortcuts"),
                OuroAppShellUtilityWindowContract(id: "about", surface: .about, title: "About Ouro Workbench")
            ],
            settings: OuroAppShellSettingsContract(
                entryPoint: "Ouro Workbench > Settings",
                appOwnedSections: ["Agents", "Terminal"]
            )
        )
    }
}
