import XCTest
@testable import OuroAppShellCore

final class ReleaseVersionIdentityTests: XCTestCase {
    func testSemanticVersionParsesAndComparesMajorMinorPatchAndPrereleaseCore() throws {
        XCTAssertGreaterThan(try XCTUnwrap(SemanticVersion("1.0.0")), try XCTUnwrap(SemanticVersion("0.999.999")))
        XCTAssertGreaterThan(try XCTUnwrap(SemanticVersion("1.2.0")), try XCTUnwrap(SemanticVersion("1.1.9")))
        XCTAssertGreaterThan(try XCTUnwrap(SemanticVersion("1.2.3")), try XCTUnwrap(SemanticVersion("1.2.2")))
        XCTAssertEqual(SemanticVersion("1.2.3-beta.1"), SemanticVersion("1.2.3"))
        let lhs = try XCTUnwrap(SemanticVersion("1.2.3"))
        let rhs = try XCTUnwrap(SemanticVersion("1.2.3"))
        XCTAssertFalse(lhs < rhs)
        XCTAssertNil(SemanticVersion("1.2"))
        XCTAssertNil(SemanticVersion("1.x.0"))
        XCTAssertNil(SemanticVersion(""))
    }

    func testReleaseVersionIdentityLabelsAndVersionComparison() {
        let plain = ReleaseVersionIdentity(version: "0.9.22")
        let built = ReleaseVersionIdentity(version: "0.9.22", build: "340")

        XCTAssertEqual(plain.label, "0.9.22")
        XCTAssertEqual(plain.display, "Version 0.9.22")
        XCTAssertEqual(built.label, "0.9.22 (build 340)")
        XCTAssertEqual(built.display, "Version 0.9.22 (build 340)")
        XCTAssertEqual(ReleaseVersionIdentity(version: "0.9.23").isNewer(than: plain), true)
        XCTAssertEqual(ReleaseVersionIdentity(version: "0.9.21").isNewer(than: plain), false)
        XCTAssertEqual(ReleaseVersionIdentity(version: "banana").isNewer(than: plain), nil)
        XCTAssertEqual(plain.isNewer(than: ReleaseVersionIdentity(version: "banana")), nil)
    }

    func testReleaseVersionIdentityBuildComparison() {
        XCTAssertEqual(
            ReleaseVersionIdentity(version: "0.9.22", build: "341")
                .isNewer(than: ReleaseVersionIdentity(version: "0.9.22", build: "340")),
            true
        )
        XCTAssertEqual(
            ReleaseVersionIdentity(version: "0.9.22", build: "340")
                .isNewer(than: ReleaseVersionIdentity(version: "0.9.22", build: "340")),
            false
        )
        XCTAssertEqual(
            ReleaseVersionIdentity(version: "0.9.22", build: nil)
                .isNewer(than: ReleaseVersionIdentity(version: "0.9.22", build: "340")),
            false
        )
        XCTAssertEqual(
            ReleaseVersionIdentity(version: "0.9.22", build: "banana")
                .isNewer(than: ReleaseVersionIdentity(version: "0.9.22", build: "340")),
            false
        )
        XCTAssertEqual(ReleaseVersionIdentity(version: "0.9.22", build: "").label, "0.9.22")
    }
}
