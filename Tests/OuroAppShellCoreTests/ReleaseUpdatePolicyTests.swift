import XCTest
@testable import OuroAppShellCore

final class ReleaseUpdatePolicyTests: XCTestCase {
    func testStablePolicyDefaultsToPlainAssetsAndSkipsPrereleases() throws {
        let policy = ReleaseUpdatePolicy.stable()

        XCTAssertEqual(policy.assetNamingPolicy, .simpleArchiveAndManifest())
        XCTAssertFalse(policy.includePrereleases)

        let decoded = try JSONDecoder().decode(
            ReleaseUpdatePolicy.self,
            from: try JSONEncoder().encode(policy)
        )
        XCTAssertEqual(decoded, policy)
    }

    func testStablePolicyCanCarryVersionedAssetNaming() {
        let policy = ReleaseUpdatePolicy.stable(assetNamingPolicy: .versionedArchiveAndManifest(namePrefix: "Ouro-MD-"))

        XCTAssertFalse(policy.includePrereleases)
        XCTAssertTrue(policy.assetNamingPolicy.isInstallableAssetName("Ouro-MD-0.10.0.zip", version: "0.10.0", build: nil))
    }

    func testWorkbenchPolicyPairsPrereleasesWithBuildAwareAssetNaming() {
        let policy = ReleaseUpdatePolicy.workbench()

        XCTAssertTrue(policy.includePrereleases)
        XCTAssertTrue(policy.assetNamingPolicy.isInstallableAssetName("OuroWorkbench-0.1.122-build.199-779ed85.zip", version: "0.1.122", build: "199"))
        XCTAssertFalse(policy.assetNamingPolicy.isInstallableAssetName("OuroWorkbench-0.1.122-build.198-779ed85.zip", version: "0.1.122", build: "199"))
    }

    func testCustomPolicyKeepsBothKnobsExplicit() {
        let policy = ReleaseUpdatePolicy(
            assetNamingPolicy: .versionedArchiveAndManifest(namePrefix: "Preview-", buildMarker: "-b.", requiresMatchingBuild: true),
            includePrereleases: true
        )

        XCTAssertTrue(policy.includePrereleases)
        XCTAssertTrue(policy.assetNamingPolicy.isInstallableAssetName("Preview-1.0.0-b.7-app.zip", version: "1.0.0", build: "7"))
    }
}
