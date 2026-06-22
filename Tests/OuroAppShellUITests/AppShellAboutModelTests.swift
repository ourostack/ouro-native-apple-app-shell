import Foundation
import XCTest
import OuroAppShellCore
@testable import OuroAppShellUI

final class AppShellAboutModelTests: XCTestCase {
    func testAboutModelDerivesIdentityBackedDefaults() {
        let identity = AppShellIdentity(
            appName: "Ouro MD",
            bundleIdentifier: "org.ourostack.ouro-md",
            repository: "ourostack/ouro-md",
            version: "0.9.22"
        )
        let whatsNew = AppShellWhatsNewModel(
            title: "What's New in 0.9.22",
            releasedText: "Released 2026-06-22",
            highlights: ["Better update clarity"],
            releaseNotesPreview: "## Notes"
        )

        let model = AppShellAboutModel(
            identity: identity,
            versionDetail: "Build abc123",
            subtitle: "Independent Markdown editor.",
            iconSystemName: "doc.richtext",
            whatsNew: whatsNew
        )

        XCTAssertEqual(model.appName, "Ouro MD")
        XCTAssertEqual(model.versionLine, "Version 0.9.22 - Build abc123")
        XCTAssertEqual(model.repositoryURL?.absoluteString, "https://github.com/ourostack/ouro-md")
        XCTAssertEqual(model.accessibilityLabel, "About Ouro MD")
        XCTAssertEqual(model.whatsNew, whatsNew)
        XCTAssertTrue(try XCTUnwrap(model.whatsNew).hasVisibleContent)
    }

    func testAboutModelVersionLineUsesBuildWhenPresent() {
        let identity = AppShellIdentity(
            appName: "Ouro Workbench",
            bundleIdentifier: "com.ourostack.workbench",
            repository: "ourostack/ouro-workbench",
            version: "0.1.156",
            build: "456"
        )

        XCTAssertEqual(
            AppShellAboutModel.versionLine(identity: identity),
            "Version 0.1.156 (build 456)"
        )
    }

    func testWhatsNewVisibility() {
        XCTAssertFalse(AppShellWhatsNewModel(title: "What's New", highlights: []).hasVisibleContent)
        XCTAssertTrue(AppShellWhatsNewModel(title: "What's New", highlights: [], releaseNotesPreview: "Notes").hasVisibleContent)
    }
}
