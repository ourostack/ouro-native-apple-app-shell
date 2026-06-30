import Foundation
import XCTest
@testable import OuroAppShellCore

final class AppUpdateTests: XCTestCase {
    private func snapshot(
        status: ReleaseUpdateStatus,
        latest: String?,
        latestBuild: String? = nil,
        policy: ReleaseAssetNamingPolicy = .simpleArchiveAndManifest(),
        assets: [ReleaseUpdateAsset]
    ) -> ReleaseUpdateSnapshot {
        ReleaseUpdateSnapshot(
            status: status,
            currentVersion: "0.9.0",
            latestVersion: latest,
            latestBuild: latestBuild,
            tagName: latest.map { "v\($0)" },
            htmlURL: "https://github.com/ourostack/ouro-md/releases/latest",
            assets: assets,
            assetNamingPolicy: policy,
            detail: ""
        )
    }

    private var mdInstallableAssets: [ReleaseUpdateAsset] {
        [
            ReleaseUpdateAsset(name: "Ouro-MD-0.10.0.zip", downloadURL: "https://example.com/Ouro-MD-0.10.0.zip", size: 7_400_000),
            ReleaseUpdateAsset(name: "Ouro-MD-0.10.0.manifest.json", downloadURL: "https://example.com/Ouro-MD-0.10.0.manifest.json", size: 350)
        ]
    }

    private var workbenchInstallableAssets: [ReleaseUpdateAsset] {
        [
            ReleaseUpdateAsset(name: "OuroWorkbench-0.1.122-build.199-779ed85.zip", downloadURL: "https://example.com/OuroWorkbench-0.1.122-build.199-779ed85.zip", size: 3_600_000),
            ReleaseUpdateAsset(name: "OuroWorkbench-0.1.122-build.199-779ed85.manifest.json", downloadURL: "https://example.com/OuroWorkbench-0.1.122-build.199-779ed85.manifest.json", size: 320)
        ]
    }

    func testPlanPicksZipAndManifestAssets() throws {
        let plan = try AppUpdatePlanner.plan(
            from: snapshot(status: .updateAvailable, latest: "0.10.0", assets: mdInstallableAssets)
        ).get()

        XCTAssertEqual(plan.version, "0.10.0")
        XCTAssertNil(plan.build)
        XCTAssertEqual(plan.archiveName, "Ouro-MD-0.10.0.zip")
        XCTAssertEqual(plan.archiveURL.lastPathComponent, "Ouro-MD-0.10.0.zip")
        XCTAssertEqual(plan.manifestURL.lastPathComponent, "Ouro-MD-0.10.0.manifest.json")
    }

    func testPlanFiltersThroughSnapshotPolicy() throws {
        let assets = [
            ReleaseUpdateAsset(name: "OuroWorkbench-0.1.122-build.198-deadbee.zip", downloadURL: "https://example.com/wrong.zip", size: 1),
            ReleaseUpdateAsset(name: "OuroWorkbench-0.1.122-build.199-779ed85.zip", downloadURL: "https://example.com/right.zip", size: 1),
            ReleaseUpdateAsset(name: "OuroWorkbench-0.1.122-build.199-779ed85.manifest.json", downloadURL: "https://example.com/right.manifest.json", size: 1)
        ]
        let plan = try AppUpdatePlanner.plan(
            from: snapshot(status: .updateAvailable, latest: "0.1.122", latestBuild: "199", policy: .buildMatchedArchiveAndManifest(namePrefix: "OuroWorkbench-"), assets: assets)
        ).get()

        XCTAssertEqual(plan.build, "199")
        XCTAssertEqual(plan.archiveURL.absoluteString, "https://example.com/right.zip")
        XCTAssertEqual(plan.manifestURL.absoluteString, "https://example.com/right.manifest.json")
    }

    func testPlanFailureCasesAndDescriptions() {
        XCTAssertEqual(
            AppUpdatePlanner.plan(from: snapshot(status: .current, latest: "0.9.0", assets: mdInstallableAssets)),
            .failure(.notAnUpdate)
        )
        XCTAssertEqual(
            AppUpdatePlanner.plan(from: snapshot(status: .updateAvailable, latest: nil, assets: mdInstallableAssets)),
            .failure(.notAnUpdate)
        )
        XCTAssertEqual(
            AppUpdatePlanner.plan(from: snapshot(status: .updateAvailable, latest: "0.10.0", assets: [mdInstallableAssets[1]])),
            .failure(.missingArchiveAsset)
        )
        XCTAssertEqual(
            AppUpdatePlanner.plan(from: snapshot(status: .updateAvailable, latest: "0.10.0", assets: [mdInstallableAssets[0]])),
            .failure(.missingManifestAsset)
        )
        XCTAssertEqual(AppUpdatePlanError.notAnUpdate.errorDescription, "No newer release is available to install.")
        XCTAssertEqual(AppUpdatePlanError.missingArchiveAsset.errorDescription, "The release is missing a downloadable app archive (.zip).")
        XCTAssertEqual(AppUpdatePlanError.missingManifestAsset.errorDescription, "The release is missing its artifact manifest (.manifest.json).")
        XCTAssertEqual(AppUpdatePlanError.badAssetURL.errorDescription, "The release asset download URL was not valid.")
    }

    func testPlanRejectsBadAndPlainHTTPURLsByDefaultButCanAllowHTTP() throws {
        let bad = [
            ReleaseUpdateAsset(name: "Ouro-MD-0.10.0.zip", downloadURL: "not a url", size: 1),
            ReleaseUpdateAsset(name: "Ouro-MD-0.10.0.manifest.json", downloadURL: "https://example.com/manifest.json", size: 1)
        ]
        XCTAssertEqual(
            AppUpdatePlanner.plan(from: snapshot(status: .updateAvailable, latest: "0.10.0", assets: bad)),
            .failure(.badAssetURL)
        )

        let http = [
            ReleaseUpdateAsset(name: "Ouro-MD-0.10.0.zip", downloadURL: "http://example.com/app.zip", size: 1),
            ReleaseUpdateAsset(name: "Ouro-MD-0.10.0.manifest.json", downloadURL: "http://example.com/manifest.json", size: 1)
        ]
        XCTAssertEqual(
            AppUpdatePlanner.plan(from: snapshot(status: .updateAvailable, latest: "0.10.0", assets: http)),
            .failure(.badAssetURL)
        )
        let allowed = try AppUpdatePlanner.plan(
            from: snapshot(status: .updateAvailable, latest: "0.10.0", assets: http),
            requireHTTPS: false
        ).get()
        XCTAssertEqual(allowed.archiveURL.scheme, "http")

        let missingHost = [
            ReleaseUpdateAsset(name: "Ouro-MD-0.10.0.zip", downloadURL: "file:///tmp/app.zip", size: 1),
            ReleaseUpdateAsset(name: "Ouro-MD-0.10.0.manifest.json", downloadURL: "https://example.com/manifest.json", size: 1)
        ]
        XCTAssertEqual(
            AppUpdatePlanner.plan(from: snapshot(status: .updateAvailable, latest: "0.10.0", assets: missingHost), requireHTTPS: false),
            .failure(.badAssetURL)
        )
    }

    func testAutoUpdatePolicy() {
        XCTAssertFalse(AutoUpdatePolicy.shouldCheck(now: Date(timeIntervalSince1970: 1), lastCheck: nil, minimumInterval: 3600, enabled: false))
        XCTAssertTrue(AutoUpdatePolicy.shouldCheck(now: Date(timeIntervalSince1970: 1), lastCheck: nil, minimumInterval: 3600, enabled: true))
        let last = Date(timeIntervalSince1970: 100_000)
        XCTAssertFalse(AutoUpdatePolicy.shouldCheck(now: last.addingTimeInterval(3599), lastCheck: last, minimumInterval: 3600, enabled: true))
        XCTAssertTrue(AutoUpdatePolicy.shouldCheck(now: last.addingTimeInterval(3600), lastCheck: last, minimumInterval: 3600, enabled: true))
    }

    func testInstallCapabilityModesDescribeRuntimeSurface() {
        XCTAssertFalse(ReleaseInstallCapability.none.canInstallFromShellControl)
        XCTAssertFalse(ReleaseInstallCapability.reviewThenInstall.canInstallFromShellControl)
        XCTAssertTrue(ReleaseInstallCapability.directInstallAndRelaunch.canInstallFromShellControl)
        XCTAssertTrue(ReleaseInstallCapability.readyToRelaunch.canInstallFromShellControl)
        XCTAssertTrue(ReleaseInstallCapability.reviewThenInstall.requiresAppReviewPrompt)
        XCTAssertEqual(ReleaseInstallCapability.none.userFacingSummary, "Updates can be checked, but this surface cannot install them.")
        XCTAssertEqual(ReleaseInstallCapability.reviewThenInstall.userFacingSummary, "Review update details in the app before installing.")
        XCTAssertEqual(ReleaseInstallCapability.directInstallAndRelaunch.userFacingSummary, "Install and relaunch directly from shell update controls.")
        XCTAssertEqual(ReleaseInstallCapability.readyToRelaunch.userFacingSummary, "Relaunch directly from shell update controls after staging completes.")
    }

    func testStagedUpdatePrimitivesCaptureSharedInstallState() {
        let staged = AppStagedUpdate(
            version: "0.10.0",
            archiveURL: URL(fileURLWithPath: "/tmp/Ouro-MD.zip"),
            appBundleURL: URL(fileURLWithPath: "/tmp/Ouro MD.app"),
            backupBundleURL: URL(fileURLWithPath: "/tmp/Ouro MD.previous.app")
        )
        let request = AppUpdateApplyRequest(stagedUpdate: staged, mode: .onQuit)

        XCTAssertEqual(staged.version, "0.10.0")
        XCTAssertEqual(request.mode, .onQuit)
        XCTAssertEqual(request.stagedUpdate.backupBundleURL?.lastPathComponent, "Ouro MD.previous.app")
    }

    func testManifestDecodesWithExtraReleaseFields() throws {
        let json = """
        {
          "appName": "Ouro MD",
          "bundleIdentifier": "org.ourostack.ouro-md",
          "version": "0.10.0",
          "build": "0.10.0",
          "gitSha": "abcdef1",
          "archive": "Ouro-MD-0.10.0.zip",
          "sha256": "05abb1975c8cb04afc0b5988428e6e0e9af5b46217ab519873c66f885a4d2050",
          "bytes": 7400000,
          "createdAt": "2026-06-14T00:00:00Z"
        }
        """

        let manifest = try JSONDecoder().decode(AppUpdateManifest.self, from: Data(json.utf8))

        XCTAssertEqual(manifest.appName, "Ouro MD")
        XCTAssertEqual(manifest.version, "0.10.0")
        XCTAssertEqual(manifest.build, "0.10.0")
        XCTAssertEqual(manifest.bytes, 7_400_000)

        let missingBuild = """
        {
          "appName": "Ouro MD",
          "bundleIdentifier": "org.ourostack.ouro-md",
          "version": "0.10.0",
          "archive": "Ouro-MD-0.10.0.zip",
          "sha256": "05abb1975c8cb04afc0b5988428e6e0e9af5b46217ab519873c66f885a4d2050",
          "bytes": 7400000
        }
        """
        XCTAssertThrowsError(try JSONDecoder().decode(AppUpdateManifest.self, from: Data(missingBuild.utf8)))
    }

    private func manifest(
        sha: String = "abc123",
        bytes: Int = 7_400_000,
        bundleID: String = "org.ourostack.ouro-md",
        version: String = "0.10.0",
        build: String = "0.10.0",
        archive: String = "Ouro-MD-0.10.0.zip"
    ) -> AppUpdateManifest {
        AppUpdateManifest(
            appName: "Ouro MD",
            bundleIdentifier: bundleID,
            version: version,
            build: build,
            archive: archive,
            sha256: sha,
            bytes: bytes
        )
    }

    func testVerifyPassesForVersionAndBuildUpdates() {
        XCTAssertNil(AppUpdateVerification.verify(
            manifest: manifest(sha: "ABC123"),
            downloadedArchiveName: "Ouro-MD-0.10.0.zip",
            downloadedSHA256: "abc123",
            downloadedBytes: 7_400_000,
            expectedBundleIdentifier: "org.ourostack.ouro-md",
            currentVersion: "0.9.0",
            compareBuilds: false
        ))

        XCTAssertNil(AppUpdateVerification.verify(
            manifest: manifest(version: "0.9.0", build: "199"),
            downloadedArchiveName: "Ouro-MD-0.10.0.zip",
            downloadedSHA256: "abc123",
            downloadedBytes: 7_400_000,
            expectedBundleIdentifier: "org.ourostack.ouro-md",
            currentVersion: "0.9.0",
            currentBuild: "198"
        ))
    }

    func testVerifyFailureCasesAndDescriptions() {
        XCTAssertEqual(
            AppUpdateVerification.verify(
                manifest: manifest(archive: "Ouro-MD-0.10.0.zip"),
                downloadedArchiveName: "different.zip",
                downloadedSHA256: "abc123",
                downloadedBytes: 7_400_000,
                expectedBundleIdentifier: "org.ourostack.ouro-md",
                currentVersion: "0.9.0"
            ),
            .archiveNameMismatch(expected: "Ouro-MD-0.10.0.zip", got: "different.zip")
        )
        XCTAssertEqual(
            AppUpdateVerification.verify(
                manifest: manifest(sha: "abc123"),
                downloadedArchiveName: "Ouro-MD-0.10.0.zip",
                downloadedSHA256: "deadbeef",
                downloadedBytes: 7_400_000,
                expectedBundleIdentifier: "org.ourostack.ouro-md",
                currentVersion: "0.9.0"
            ),
            .sha256Mismatch(expected: "abc123", got: "deadbeef")
        )
        XCTAssertEqual(
            AppUpdateVerification.verify(
                manifest: manifest(bytes: 7_400_000),
                downloadedArchiveName: "Ouro-MD-0.10.0.zip",
                downloadedSHA256: "abc123",
                downloadedBytes: 42,
                expectedBundleIdentifier: "org.ourostack.ouro-md",
                currentVersion: "0.9.0"
            ),
            .byteCountMismatch(expected: 7_400_000, got: 42)
        )
        XCTAssertEqual(
            AppUpdateVerification.verify(
                manifest: manifest(bundleID: "com.example.bad"),
                downloadedArchiveName: "Ouro-MD-0.10.0.zip",
                downloadedSHA256: "abc123",
                downloadedBytes: 7_400_000,
                expectedBundleIdentifier: "org.ourostack.ouro-md",
                currentVersion: "0.9.0"
            ),
            .bundleIdentifierMismatch(expected: "org.ourostack.ouro-md", got: "com.example.bad")
        )
        XCTAssertEqual(
            AppUpdateVerification.verify(
                manifest: manifest(version: "banana"),
                downloadedArchiveName: "Ouro-MD-0.10.0.zip",
                downloadedSHA256: "abc123",
                downloadedBytes: 7_400_000,
                expectedBundleIdentifier: "org.ourostack.ouro-md",
                currentVersion: "0.9.0"
            ),
            .unreadableVersion(manifest: "banana", current: "0.9.0")
        )
        XCTAssertEqual(
            AppUpdateVerification.verify(
                manifest: manifest(version: "0.9.0"),
                downloadedArchiveName: "Ouro-MD-0.10.0.zip",
                downloadedSHA256: "abc123",
                downloadedBytes: 7_400_000,
                expectedBundleIdentifier: "org.ourostack.ouro-md",
                currentVersion: "0.9.0",
                compareBuilds: false
            ),
            .notNewerThanCurrent(current: "0.9.0", candidate: "0.9.0")
        )
        XCTAssertEqual(
            AppUpdateVerification.verify(
                manifest: manifest(version: "0.9.0", build: "199"),
                downloadedArchiveName: "Ouro-MD-0.10.0.zip",
                downloadedSHA256: "abc123",
                downloadedBytes: 7_400_000,
                expectedBundleIdentifier: "org.ourostack.ouro-md",
                currentVersion: "0.9.0",
                currentBuild: "199"
            ),
            .notNewerThanCurrent(current: "Version 0.9.0 (build 199)", candidate: "Version 0.9.0 (build 199)")
        )

        XCTAssertEqual(
            AppUpdateVerification.Failure.archiveNameMismatch(expected: "expected.zip", got: "actual.zip").errorDescription,
            "Downloaded archive name actual.zip did not match the manifest (expected.zip)."
        )
        XCTAssertEqual(AppUpdateVerification.Failure.sha256Mismatch(expected: "abc", got: "def").errorDescription, "Downloaded archive failed its SHA-256 integrity check.")
        XCTAssertEqual(AppUpdateVerification.Failure.byteCountMismatch(expected: 10, got: 9).errorDescription, "Downloaded archive size (9 bytes) did not match the manifest (10 bytes).")
        XCTAssertEqual(AppUpdateVerification.Failure.bundleIdentifierMismatch(expected: "org.ouro", got: "other.bundle").errorDescription, "Update bundle identifier other.bundle did not match this app (org.ouro).")
        XCTAssertEqual(AppUpdateVerification.Failure.unreadableVersion(manifest: "banana", current: "0.9.1").errorDescription, "Could not compare the update version (banana) to the current version (0.9.1).")
        XCTAssertEqual(AppUpdateVerification.Failure.notNewerThanCurrent(current: "0.9.1", candidate: "0.9.1").errorDescription, "Update version 0.9.1 is not newer than the installed 0.9.1.")
    }

    func testWorkbenchFixturesArePlanCompatible() throws {
        let plan = try AppUpdatePlanner.plan(
            from: snapshot(
                status: .updateAvailable,
                latest: "0.1.122",
                latestBuild: "199",
                policy: .buildMatchedArchiveAndManifest(namePrefix: "OuroWorkbench-"),
                assets: workbenchInstallableAssets
            )
        ).get()

        XCTAssertEqual(plan.archiveName, "OuroWorkbench-0.1.122-build.199-779ed85.zip")
        XCTAssertEqual(plan.build, "199")
    }
}
