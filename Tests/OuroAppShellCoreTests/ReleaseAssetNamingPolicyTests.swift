import XCTest
@testable import OuroAppShellCore

final class ReleaseAssetNamingPolicyTests: XCTestCase {
    func testSimplePolicyAcceptsPlainArchivesAndManifests() {
        let policy = ReleaseAssetNamingPolicy.simpleArchiveAndManifest()

        XCTAssertTrue(policy.isInstallableAssetName("Ouro-MD-0.10.0.zip", version: "0.10.0", build: nil))
        XCTAssertTrue(policy.isInstallableAssetName("Ouro-MD-0.10.0.manifest.json", version: "0.10.0", build: nil))
        XCTAssertFalse(policy.isInstallableAssetName("README.txt", version: "0.10.0", build: nil))
        XCTAssertNil(policy.latestBuild(fromAssetNames: ["Ouro-MD-0.10.0.zip"], version: "0.10.0"))
    }

    func testVersionedPolicyCanMatchWithoutBuildMarker() {
        let policy = ReleaseAssetNamingPolicy.versionedArchiveAndManifest(namePrefix: "Ouro-MD-")

        XCTAssertTrue(policy.isInstallableAssetName("Ouro-MD-0.10.0.zip", version: "0.10.0", build: nil))
        XCTAssertFalse(policy.isInstallableAssetName("Other-0.10.0.zip", version: "0.10.0", build: nil))
    }

    func testBuildMatchedPolicyMatchesVersionAndBuildAwareAssets() {
        let policy = ReleaseAssetNamingPolicy.buildMatchedArchiveAndManifest(namePrefix: "OuroWorkbench-")

        XCTAssertTrue(policy.isInstallableAssetName("OuroWorkbench-0.1.122-build.199-779ed85.zip", version: "0.1.122", build: "199"))
        XCTAssertTrue(policy.isInstallableAssetName("OuroWorkbench-0.1.122-build.199-779ed85.manifest.json", version: "0.1.122", build: "199"))
        XCTAssertFalse(policy.isInstallableAssetName("OuroWorkbench-0.1.121-build.199-779ed85.zip", version: "0.1.122", build: "199"))
        XCTAssertFalse(policy.isInstallableAssetName("OuroWorkbench-0.1.122-199-779ed85.zip", version: "0.1.122", build: "199"))
        XCTAssertFalse(policy.isInstallableAssetName("OuroWorkbench-0.1.122-build.198-779ed85.zip", version: "0.1.122", build: "199"))
        XCTAssertTrue(policy.isInstallableAssetName("OuroWorkbench-0.1.122-build.198-779ed85.zip", version: "0.1.122", build: nil))
    }

    func testLatestBuildExtractsHighestNumericBuildFromMatchingAssetsOnly() {
        let policy = ReleaseAssetNamingPolicy.buildMatchedArchiveAndManifest(namePrefix: "OuroWorkbench-")
        let huge = String(repeating: "9", count: 80)

        let build = policy.latestBuild(
            fromAssetNames: [
                "README.txt",
                "OtherWorkbench-0.1.155-build.999.zip",
                "OuroWorkbench-0.1.154-build.999.zip",
                "OuroWorkbench-0.1.155-build.-bad.zip",
                "OuroWorkbench-0.1.155-build.\(huge).zip",
                "OuroWorkbench-0.1.155-build.238-8488f1c.zip",
                "OuroWorkbench-0.1.155-build.340-cdf1190.manifest.json"
            ],
            version: "0.1.155"
        )

        XCTAssertEqual(build, "340")
    }

    func testLegacyWorkbenchPolicyUsesBuildMatchedNaming() {
        XCTAssertEqual(
            ReleaseAssetNamingPolicy.workbench(),
            .buildMatchedArchiveAndManifest(namePrefix: "OuroWorkbench-")
        )
    }
}
