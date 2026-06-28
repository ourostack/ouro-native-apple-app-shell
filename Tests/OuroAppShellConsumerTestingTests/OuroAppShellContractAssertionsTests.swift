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
    }

    func testAdapterLibraryFixtureUsesHelper() {
        let contract = Self.workbenchStyleContract()

        OuroAppShellContractAssertions.assertRequiresShellFirstSurfaces(
            contract,
            [.appIdentity, .releaseUpdates, .about, .keyboardShortcuts, .windowChrome, .settings]
        )
        OuroAppShellContractAssertions.assertValid(contract)
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
                commandCount: 12,
                sections: ["File", "Editing"],
                entryPoint: "Help > Keyboard Shortcuts"
            ),
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
                commandCount: 18,
                sections: ["Global", "Workbench"],
                entryPoint: "Help > Keyboard Shortcuts"
            ),
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
