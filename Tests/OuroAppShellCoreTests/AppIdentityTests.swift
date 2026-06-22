import Foundation
import XCTest
@testable import OuroAppShellCore

final class AppIdentityTests: XCTestCase {
    func testIdentityDefaultsDerivedURLsAndUserAgent() throws {
        let identity = AppShellIdentity(
            appName: "Ouro MD",
            bundleIdentifier: "org.ourostack.ouro-md",
            repository: "ourostack/ouro-md",
            version: "0.9.22"
        )

        XCTAssertEqual(identity.userAgent, "OuroMD/0.9.22")
        XCTAssertEqual(identity.distributionChannel, .directDownload)
        XCTAssertEqual(identity.releasesAPIURL.absoluteString, "https://api.github.com/repos/ourostack/ouro-md/releases?per_page=10")
        XCTAssertEqual(identity.releasePageURL.absoluteString, "https://github.com/ourostack/ouro-md/releases/latest")
    }

    func testIdentityPreservesExplicitFieldsAndCodableChannel() throws {
        let identity = AppShellIdentity(
            appName: "!!!",
            bundleIdentifier: "com.ourostack.workbench",
            repository: "ourostack/ouro-workbench",
            version: "0.1.156",
            build: "456",
            userAgent: "OuroWorkbench/0.1.156",
            distributionChannel: .developerIDDirect,
            releasePageURL: URL(string: "https://example.test/releases")!
        )

        XCTAssertEqual(identity.userAgent, "OuroWorkbench/0.1.156")
        XCTAssertEqual(identity.build, "456")
        XCTAssertEqual(identity.distributionChannel.rawValue, "developerIDDirect")
        XCTAssertEqual(identity.releasePageURL.absoluteString, "https://example.test/releases")
        XCTAssertEqual(DistributionChannel.appStore.rawValue, "appStore")

        let encoded = try JSONEncoder().encode(identity)
        let decoded = try JSONDecoder().decode(AppShellIdentity.self, from: encoded)
        XCTAssertEqual(decoded, identity)
    }

    func testDefaultUserAgentFallsBackWhenAppNameHasNoTokenCharacters() {
        let identity = AppShellIdentity(
            appName: "---",
            bundleIdentifier: "org.ourostack.placeholder",
            repository: "ourostack/placeholder",
            version: "1.0.0"
        )

        XCTAssertEqual(identity.userAgent, "OuroApp/1.0.0")
    }
}
