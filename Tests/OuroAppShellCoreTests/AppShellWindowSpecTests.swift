import AppKit
import SwiftUI
import XCTest
@testable import OuroAppShellAppKit

final class AppShellWindowSpecTests: XCTestCase {
    func testWindowSpecDefaultsAndOverrides() async {
        await MainActor.run {
            let defaults = AppShellWindowSpec(title: "About", width: 520, height: 500)
            XCTAssertEqual(defaults.title, "About")
            XCTAssertEqual(defaults.width, 520)
            XCTAssertEqual(defaults.height, 500)
            XCTAssertNil(defaults.minSize)
            XCTAssertTrue(defaults.styleMask.contains(.titled))
            XCTAssertTrue(defaults.styleMask.contains(.closable))
            XCTAssertTrue(defaults.shouldCenter)
            XCTAssertTrue(defaults.shouldActivateApp)

            let custom = AppShellWindowSpec(
                title: "Progress",
                width: 420,
                height: 160,
                minSize: NSSize(width: 400, height: 140),
                styleMask: [.titled],
                shouldCenter: false,
                shouldActivateApp: false
            )
            XCTAssertEqual(custom.minSize, NSSize(width: 400, height: 140))
            XCTAssertEqual(custom.styleMask, [.titled])
            XCTAssertFalse(custom.shouldCenter)
            XCTAssertFalse(custom.shouldActivateApp)
        }
    }

    func testPresenterReusesWindowAndAppliesUpdatedSpec() async {
        await MainActor.run {
            let presenter = AppShellWindowPresenter()
            let first = presenter.present(
                id: "shortcuts",
                spec: AppShellWindowSpec(
                    title: "Keyboard Shortcuts",
                    width: 560,
                    height: 620,
                    minSize: NSSize(width: 520, height: 500),
                    styleMask: [.titled, .closable, .resizable],
                    shouldCenter: false,
                    shouldActivateApp: false
                )
            ) {
                EmptyView()
            }

            XCTAssertTrue(first.styleMask.contains(.resizable))
            XCTAssertEqual(first.minSize, NSSize(width: 520, height: 500))

            let second = presenter.present(
                id: "shortcuts",
                spec: AppShellWindowSpec(
                    title: "Commands",
                    width: 560,
                    height: 620,
                    minSize: NSSize(width: 540, height: 510),
                    styleMask: [.titled, .closable],
                    shouldCenter: false,
                    shouldActivateApp: false
                )
            ) {
                Text("Updated")
            }

            XCTAssertTrue(first === second)
            XCTAssertEqual(second.title, "Commands")
            XCTAssertFalse(second.styleMask.contains(.resizable))
            XCTAssertEqual(second.minSize, NSSize(width: 540, height: 510))

            presenter.close(id: "shortcuts")
            XCTAssertEqual(presenter.window(for: "shortcuts"), second)
        }
    }

    func testPresenterClearsMinSizeWhenReusedSpecOmitsIt() async {
        await MainActor.run {
            let presenter = AppShellWindowPresenter()
            let first = presenter.present(
                id: "utility",
                spec: AppShellWindowSpec(
                    title: "Resizable",
                    width: 560,
                    height: 620,
                    minSize: NSSize(width: 520, height: 500),
                    styleMask: [.titled, .closable, .resizable],
                    shouldCenter: false,
                    shouldActivateApp: false
                )
            ) {
                EmptyView()
            }
            XCTAssertEqual(first.minSize, NSSize(width: 520, height: 500))

            let second = presenter.present(
                id: "utility",
                spec: AppShellWindowSpec(
                    title: "Unconstrained",
                    width: 360,
                    height: 140,
                    shouldCenter: false,
                    shouldActivateApp: false
                )
            ) {
                Text("Small")
            }

            XCTAssertTrue(first === second)
            XCTAssertEqual(second.minSize.width, 0)
            XCTAssertLessThan(second.minSize.height, 500)
            presenter.close(id: "utility")
        }
    }
}
