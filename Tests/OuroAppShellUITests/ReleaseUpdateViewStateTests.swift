import XCTest
@testable import OuroAppShellUI

final class ReleaseUpdateViewStateTests: XCTestCase {
    func testStateKindsExposeLabelsTonesAndProgress() {
        XCTAssertEqual(ReleaseUpdateStateKind.notChecked.label, "Not Checked")
        XCTAssertEqual(ReleaseUpdateStateKind.checking.label, "Checking")
        XCTAssertEqual(ReleaseUpdateStateKind.current.label, "Current")
        XCTAssertEqual(ReleaseUpdateStateKind.updateAvailable.label, "Available")
        XCTAssertEqual(ReleaseUpdateStateKind.installing.label, "Installing")
        XCTAssertEqual(ReleaseUpdateStateKind.readyToRelaunch.label, "Ready")
        XCTAssertEqual(ReleaseUpdateStateKind.installed.label, "Installed")
        XCTAssertEqual(ReleaseUpdateStateKind.unavailable.label, "Unavailable")
        XCTAssertEqual(ReleaseUpdateStateKind.failed.label, "Failed")

        XCTAssertEqual(ReleaseUpdateStateKind.current.tone, .success)
        XCTAssertEqual(ReleaseUpdateStateKind.installed.tone, .success)
        XCTAssertEqual(ReleaseUpdateStateKind.updateAvailable.tone, .attention)
        XCTAssertEqual(ReleaseUpdateStateKind.readyToRelaunch.tone, .attention)
        XCTAssertEqual(ReleaseUpdateStateKind.failed.tone, .danger)
        XCTAssertEqual(ReleaseUpdateStateKind.checking.tone, .neutral)
        XCTAssertTrue(ReleaseUpdateStateKind.checking.showsProgress)
        XCTAssertTrue(ReleaseUpdateStateKind.installing.showsProgress)
        XCTAssertFalse(ReleaseUpdateStateKind.current.showsProgress)
    }

    func testNotCheckedFactoryAndMetadataIdentity() {
        let state = ReleaseUpdateViewState.notChecked(channel: "App Store")

        XCTAssertEqual(state.kind, .notChecked)
        XCTAssertEqual(state.statusLine, "Updates have not been checked yet.")
        XCTAssertEqual(state.metadata, [ReleaseUpdateMetadataItem(label: "Channel", value: "App Store")])
        XCTAssertEqual(state.metadata.first?.id, "Channel")
        XCTAssertFalse(state.hasPrimaryAction)
        XCTAssertNil(state.displayDetail)
    }

    func testPrimaryActionsAndDisplayDetailPreferWarnings() {
        let state = ReleaseUpdateViewState(
            kind: .updateAvailable,
            statusLine: "Version 2 is available.",
            metadata: [
                ReleaseUpdateMetadataItem(label: "Latest", value: "2.0.0"),
                ReleaseUpdateMetadataItem(label: "Channel", value: "Direct download")
            ],
            detail: "Verified before installing.",
            warning: "Archive is missing.",
            canReviewUpdate: true,
            canInstallUpdate: true,
            canOpenReleasePage: true
        )

        XCTAssertTrue(state.hasPrimaryAction)
        XCTAssertEqual(state.displayDetail, "Archive is missing.")
        XCTAssertTrue(state.canOpenReleasePage)
        XCTAssertEqual(ReleaseUpdateActionLabels().check, "Check for Updates...")
    }

    func testActionLabelsCanBeCustomized() {
        let labels = ReleaseUpdateActionLabels(
            check: "Check",
            review: "Review",
            install: "Install",
            openRelease: "Open"
        )

        XCTAssertEqual(labels.check, "Check")
        XCTAssertEqual(labels.review, "Review")
        XCTAssertEqual(labels.install, "Install")
        XCTAssertEqual(labels.openRelease, "Open")
    }
}
