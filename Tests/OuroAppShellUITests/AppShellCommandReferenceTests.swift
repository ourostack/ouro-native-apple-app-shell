import XCTest
@testable import OuroAppShellUI

final class AppShellCommandReferenceTests: XCTestCase {
    private static let items = [
        AppShellCommandReferenceItem(id: "file.open", title: "Open Document", section: "File", shortcut: "⌘O", keywords: "file picker"),
        AppShellCommandReferenceItem(id: "edit.palette", title: "Command Palette", section: "Edit", shortcut: "⇧⌘P", keywords: "commands power user"),
        AppShellCommandReferenceItem(id: "help.shortcuts", title: "Keyboard Shortcuts", section: "Help", shortcut: "⌘?", keywords: "reference")
    ]

    func testFilterUsesTitleKeywordsAndShortcutSynonyms() {
        XCTAssertEqual(AppShellCommandReferenceCatalog.filter(Self.items, query: "file picker").map(\.id), ["file.open"])
        XCTAssertEqual(AppShellCommandReferenceCatalog.filter(Self.items, query: "cmd shift palette").map(\.id), ["edit.palette"])
        XCTAssertEqual(AppShellCommandReferenceCatalog.filter(Self.items, query: "question slash").map(\.id), ["help.shortcuts"])
        XCTAssertTrue(AppShellCommandReferenceCatalog.filter(Self.items, query: "missing").isEmpty)
    }

    func testEmptyFilterAndSectionOrdering() {
        XCTAssertEqual(AppShellCommandReferenceCatalog.filter(Self.items, query: "", emptyLimit: 2).map(\.id), ["file.open", "edit.palette"])

        let sections = AppShellCommandReferenceCatalog.sections(
            for: Self.items,
            preferredOrder: ["Help", "File"]
        )
        XCTAssertEqual(sections.map(\.name), ["Help", "File", "Edit"])
        XCTAssertEqual(sections.first?.items.map(\.id), ["help.shortcuts"])
    }

    func testSpokenShortcut() {
        XCTAssertEqual(
            AppShellCommandReferenceCatalog.spokenShortcut("⌃⌥⇧⌘/?"),
            "Control Option Shift Command SlashQuestion Mark"
        )
    }

    func testViewKeepsConfigurationForApps() async {
        await MainActor.run {
            let view = AppShellCommandReferenceView(
                title: "Commands",
                subtitle: "Power user surface",
                items: Self.items,
                preferredSectionOrder: ["File"],
                searchPlaceholder: "Find",
                doneTitle: "Close",
                onDone: {}
            )

            XCTAssertEqual(view.title, "Commands")
            XCTAssertEqual(view.subtitle, "Power user surface")
            XCTAssertEqual(view.items, Self.items)
            XCTAssertEqual(view.preferredSectionOrder, ["File"])
            XCTAssertEqual(view.searchPlaceholder, "Find")
            XCTAssertEqual(view.doneTitle, "Close")
        }
    }
}
