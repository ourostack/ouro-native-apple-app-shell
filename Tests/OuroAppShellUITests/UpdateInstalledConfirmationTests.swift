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
                openAboutSystemImage: nil,
                dismissLabel: "OK",
                onOpenAbout: {},
                onDismiss: {}
            )

            XCTAssertEqual(defaultView.openAboutLabel, "Open About")
            XCTAssertEqual(defaultView.openAboutSystemImage, "info.circle")
            XCTAssertEqual(defaultView.dismissLabel, "Done")
            XCTAssertEqual(customView.openAboutLabel, "What's New")
            XCTAssertNil(customView.openAboutSystemImage)
            XCTAssertEqual(customView.dismissLabel, "OK")
        }
    }
}
