import AppKit
import SwiftUI
import XCTest
@testable import OuroAppShellUI

final class AppShellAboutLayoutTests: XCTestCase {
    func testLongHistoryHasBoundedScrollableViewportAtConsumerAndMinimumSizes() async throws {
        try await MainActor.run {
            for size in [NSSize(width: 520, height: 520), NSSize(width: 460, height: 360)] {
                for updateState in [nil, ReleaseUpdateViewState(kind: .current, statusLine: "Version 1.0 is current.")] + Self.detailedUpdateStates {
                    try Self.withHost(highlights: Self.longHistory, size: size, updateState: updateState) { host in
                        let scroll = try XCTUnwrap(Self.descendants(host).compactMap { $0 as? NSScrollView }.first)
                        let document = try XCTUnwrap(scroll.documentView)
                        XCTAssertGreaterThanOrEqual(scroll.contentView.bounds.height, 24)
                        XCTAssertGreaterThan(document.frame.height, scroll.contentView.bounds.height)
                        XCTAssertTrue(host.bounds.contains(host.convert(scroll.frame, from: scroll.superview)))
                        scroll.contentView.scroll(to: NSPoint(
                            x: 0, y: document.frame.height - scroll.contentView.bounds.height
                        ))
                        scroll.reflectScrolledClipView(scroll.contentView)
                        XCTAssertGreaterThan(scroll.contentView.bounds.minY, 0)
                        XCTAssertEqual(scroll.contentView.bounds.maxY, document.frame.height, accuracy: 1)
                        XCTAssertEqual(host.frame.size, size)
                    }
                }
            }
        }
    }

    func testShortAndNotesOnlyHistoryKeepIntrinsicPresentation() async throws {
        try await MainActor.run {
            for highlights in [[], ["First improvement", "Second improvement"]] {
                try Self.withHost(highlights: highlights, notes: "Release notes preview.") { host in
                    XCTAssertFalse(Self.descendants(host).contains { $0 is NSScrollView })
                }
            }
        }
    }

    func testHistoryDoesNotScrollWhenItFits() async throws {
        try await MainActor.run {
            try Self.withHost(highlights: Self.longHistory, size: NSSize(width: 520, height: 1400)) { host in
                XCTAssertFalse(Self.descendants(host).contains { $0 is NSScrollView })
            }
        }
    }

    func testAboutRetainsItsPreferredFittingSize() async {
        await MainActor.run {
            let host = NSHostingView(rootView: AppShellAboutView(model: AppShellAboutModel(
                appName: "Ouro MD", versionLine: "Version 1.0",
                subtitle: "Independent Markdown editor.", iconSystemName: "doc.richtext",
                whatsNew: AppShellWhatsNewModel(title: "What's New", highlights: ["One improvement"])
            )))
            host.frame = NSRect(x: 0, y: 0, width: 560, height: 540)
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.fittingSize.width, 520, accuracy: 1)
            XCTAssertEqual(host.fittingSize.height, 500, accuracy: 1)
        }
    }

    func testNativeAccessibilityExposesScrollRoleAndHistoryPosition() async throws {
        try await MainActor.run {
            try Self.withHost(highlights: Self.longHistory) { host in
                let scroll = try XCTUnwrap(Self.descendants(host).compactMap { $0 as? NSScrollView }.first)
                XCTAssertEqual(scroll.accessibilityRole(), .scrollArea)
                let scroller = try XCTUnwrap(scroll.verticalScroller)
                XCTAssertEqual(scroller.accessibilityRole(), .scrollBar)
                XCTAssertEqual(try XCTUnwrap(scroller.accessibilityValue() as? NSNumber).doubleValue, 0, accuracy: 0.01)
                let document = try XCTUnwrap(scroll.documentView)
                scroll.contentView.scroll(to: NSPoint(x: 0, y: document.frame.height - scroll.contentView.bounds.height))
                scroll.reflectScrolledClipView(scroll.contentView)
                XCTAssertEqual(try XCTUnwrap(scroller.accessibilityValue() as? NSNumber).doubleValue, 1, accuracy: 0.01)
            }
        }
    }

    private static let longHistory = (1...25).map {
        "Highlight \($0): A wrapping release improvement that remains available in the complete history."
    }

    private static let detailedUpdateStates: [ReleaseUpdateViewState?] = [
        ReleaseUpdateViewState(
            kind: .updateAvailable,
            statusLine: "Version 1.1 is available.",
            metadata: [ReleaseUpdateMetadataItem(label: "Latest", value: "1.1")],
            detail: "The archive and manifest are ready.",
            canReviewUpdate: true, canInstallUpdate: true, canOpenReleasePage: true
        ),
        ReleaseUpdateViewState(
            kind: .failed,
            statusLine: "Install failed.",
            metadata: [ReleaseUpdateMetadataItem(label: "Latest", value: "1.1")],
            warning: "Downloaded archive failed verification.",
            canReviewUpdate: true, canOpenReleasePage: true
        )
    ]

    @MainActor
    private static func withHost(
        highlights: [String],
        notes: String? = nil,
        size: NSSize = NSSize(width: 520, height: 520),
        updateState: ReleaseUpdateViewState? = nil,
        check: (NSView) throws -> Void
    ) throws {
        let host = NSHostingView(rootView: AppShellAboutView(
            model: AppShellAboutModel(
                appName: "Ouro MD",
                versionLine: "Version 1.0",
                subtitle: "Independent Markdown editor for dogfooding shared native shell surfaces.",
                iconSystemName: "doc.richtext",
                whatsNew: AppShellWhatsNewModel(
                    title: "What's New", releasedText: "Released 2026-10-09",
                    highlights: highlights, releaseNotesPreview: notes
                )
            ),
            updateState: updateState,
            updateActions: ReleaseUpdateActions(
                checkForUpdates: {}, reviewUpdate: {}, installAndRelaunch: {}, openReleasePage: {}
            ),
            aboutActions: AppShellAboutActions(openRepository: {}, copyVersion: {}, dismiss: {})
        ).frame(width: size.width, height: size.height))
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        host.layoutSubtreeIfNeeded()
        XCTAssertFalse(window.isVisible)
        XCTAssertFalse(window.isKeyWindow)
        try check(host)
    }

    @MainActor
    private static func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}
