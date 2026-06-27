import XCTest
@testable import OuroAppShellAppKit

final class AppShellWindowSpecTests: XCTestCase {
    func testWindowSpecDefaultsAndOverrides() async {
        await MainActor.run {
            let defaults = AppShellWindowSpec(title: "About", width: 520, height: 500)
            XCTAssertEqual(defaults.title, "About")
            XCTAssertEqual(defaults.width, 520)
            XCTAssertEqual(defaults.height, 500)
            XCTAssertTrue(defaults.styleMask.contains(.titled))
            XCTAssertTrue(defaults.styleMask.contains(.closable))
            XCTAssertTrue(defaults.shouldCenter)
            XCTAssertTrue(defaults.shouldActivateApp)

            let custom = AppShellWindowSpec(
                title: "Progress",
                width: 420,
                height: 160,
                styleMask: [.titled],
                shouldCenter: false,
                shouldActivateApp: false
            )
            XCTAssertEqual(custom.styleMask, [.titled])
            XCTAssertFalse(custom.shouldCenter)
            XCTAssertFalse(custom.shouldActivateApp)
        }
    }
}
