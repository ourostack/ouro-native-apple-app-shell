import XCTest
@testable import OuroAppShellCore

final class ShellBoundaryTests: XCTestCase {
    func testBoundaryOwnersClassifySharedNativeSurfaces() {
        let shellSurfaces: [AppShellSurface] = [
            .appIdentity,
            .releaseUpdates,
            .about,
            .keyboardShortcuts,
            .windowChrome
        ]

        for surface in shellSurfaces {
            let decision = AppShellBoundary.owner(for: surface)
            XCTAssertEqual(decision.owner, .shell, "\(surface)")
            XCTAssertTrue(AppShellBoundary.requiresShellFirstDesign(surface), "\(surface)")
            XCTAssertFalse(decision.reason.isEmpty)
        }
    }

    func testBoundaryOwnersClassifyAdaptersAndApps() {
        XCTAssertEqual(AppShellBoundary.owner(for: .settings).owner, .adapter)
        XCTAssertEqual(AppShellBoundary.owner(for: .telemetry).owner, .adapter)
        XCTAssertEqual(AppShellBoundary.owner(for: .documentEditing).owner, .app)
        XCTAssertEqual(AppShellBoundary.owner(for: .domainWorkflow).owner, .app)

        XCTAssertTrue(AppShellBoundary.requiresShellFirstDesign(.settings))
        XCTAssertTrue(AppShellBoundary.requiresShellFirstDesign(.telemetry))
        XCTAssertFalse(AppShellBoundary.requiresShellFirstDesign(.documentEditing))
        XCTAssertFalse(AppShellBoundary.requiresShellFirstDesign(.domainWorkflow))
    }

    func testBoundaryDecisionIsCodable() throws {
        let decision = AppShellBoundary.owner(for: .releaseUpdates)
        let encoded = try JSONEncoder().encode(decision)
        let decoded = try JSONDecoder().decode(AppShellBoundaryDecision.self, from: encoded)

        XCTAssertEqual(decoded, decision)
    }
}
