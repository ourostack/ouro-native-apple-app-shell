import XCTest
@testable import OuroAppShellUI

final class UpdateInstalledConfirmationTests: XCTestCase {
    func testDefaultAndCustomOpenAboutLabels() async {
        await MainActor.run {
            let defaultView = UpdateInstalledConfirmationView(
                appName: "Ouro Workbench",
                version: "0.1.156",
                onOpenAbout: {},
                onDismiss: {}
            )
            let customView = UpdateInstalledConfirmationView(
                appName: "Ouro MD",
                version: "0.9.22",
                openAboutLabel: "What's New",
                onOpenAbout: {},
                onDismiss: {}
            )

            XCTAssertEqual(defaultView.openAboutLabel, "Open About")
            XCTAssertEqual(customView.openAboutLabel, "What's New")
        }
    }
}
