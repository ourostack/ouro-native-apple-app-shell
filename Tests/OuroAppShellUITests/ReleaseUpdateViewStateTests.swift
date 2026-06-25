import XCTest
import OuroAppShellCore
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
        XCTAssertEqual(state.metadata.first?.id, "Channel:App Store")
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

    func testMetadataItemsCanUseExplicitIDsForDuplicateLabels() {
        let first = ReleaseUpdateMetadataItem(id: "latest-stable", label: "Latest", value: "1.0.0")
        let second = ReleaseUpdateMetadataItem(id: "latest-beta", label: "Latest", value: "2.0.0-beta.1")

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.label, second.label)
    }

    func testActionLabelsCanBeCustomized() {
        let labels = ReleaseUpdateActionLabels(
            check: "Check",
            review: "Review",
            install: "Install",
            relaunch: "Relaunch",
            openRelease: "Open"
        )

        XCTAssertEqual(labels.check, "Check")
        XCTAssertEqual(labels.review, "Review")
        XCTAssertEqual(labels.install, "Install")
        XCTAssertEqual(labels.relaunch, "Relaunch")
        XCTAssertEqual(labels.openRelease, "Open")
    }

    func testReadyToRelaunchUsesRelaunchActionCopy() {
        let labels = ReleaseUpdateActionLabels()

        XCTAssertEqual(labels.installActionLabel(for: .updateAvailable), "Install & Relaunch")
        XCTAssertEqual(labels.installActionAccessibilityLabel(for: .updateAvailable), "Install and relaunch")
        XCTAssertEqual(labels.installActionLabel(for: .readyToRelaunch), "Relaunch to Update")
        XCTAssertEqual(labels.installActionAccessibilityLabel(for: .readyToRelaunch), "Relaunch to update")
    }

    func testViewStateCanDeriveFromCurrentSnapshot() {
        let state = ReleaseUpdateViewState.from(
            snapshot: ReleaseUpdateSnapshot(
                status: .current,
                currentVersion: "0.9.24",
                latestVersion: "0.9.24",
                tagName: "v0.9.24",
                htmlURL: "https://example.test/releases/v0.9.24",
                assets: [],
                detail: "Version 0.9.24 is current."
            )
        )

        XCTAssertEqual(state.kind, .current)
        XCTAssertEqual(state.statusLine, "Version 0.9.24 is current.")
        XCTAssertEqual(state.metadata.map(\.value), ["0.9.24", "0.9.24", "Direct download"])
        XCTAssertTrue(state.canOpenReleasePage)
        XCTAssertFalse(state.canInstallUpdate)
    }

    func testViewStateCanDeriveInstallableUpdateFromSnapshotAndPlan() throws {
        let snapshot = ReleaseUpdateSnapshot(
            status: .updateAvailable,
            currentVersion: "0.9.24",
            latestVersion: "0.9.25",
            tagName: "v0.9.25",
            htmlURL: "https://example.test/releases/v0.9.25",
            assets: [
                ReleaseUpdateAsset(name: "Ouro-MD-0.9.25.zip", downloadURL: "https://example.test/app.zip", size: 10),
                ReleaseUpdateAsset(name: "Ouro-MD-0.9.25.manifest.json", downloadURL: "https://example.test/app.manifest.json", size: 5)
            ],
            detail: "Version 0.9.25 is available."
        )

        let state = ReleaseUpdateViewState.from(
            snapshot: snapshot,
            installPlan: AppUpdatePlanner.plan(from: snapshot),
            channel: "Developer ID"
        )

        XCTAssertEqual(state.kind, .updateAvailable)
        XCTAssertEqual(state.statusLine, "Version 0.9.25 is available.")
        XCTAssertEqual(state.metadata.map(\.value), ["0.9.24", "0.9.25", "Developer ID"])
        XCTAssertEqual(state.detail, "The archive and manifest are present.")
        XCTAssertTrue(state.canReviewUpdate)
        XCTAssertTrue(state.canInstallUpdate)
        XCTAssertTrue(state.canOpenReleasePage)
    }

    func testViewStateDerivesUnavailableInstallDetailFromPlanFailure() {
        let snapshot = ReleaseUpdateSnapshot(
            status: .updateAvailable,
            currentVersion: "0.9.24",
            latestVersion: "0.9.25",
            tagName: "v0.9.25",
            htmlURL: nil,
            assets: [
                ReleaseUpdateAsset(name: "Ouro-MD-0.9.25.zip", downloadURL: "https://example.test/app.zip", size: 10)
            ],
            detail: "Version 0.9.25 is available."
        )

        let state = ReleaseUpdateViewState.from(snapshot: snapshot)

        XCTAssertEqual(state.kind, .updateAvailable)
        XCTAssertEqual(state.detail, AppUpdatePlanError.missingManifestAsset.localizedDescription)
        XCTAssertTrue(state.canReviewUpdate)
        XCTAssertFalse(state.canInstallUpdate)
        XCTAssertFalse(state.canOpenReleasePage)
    }
}
