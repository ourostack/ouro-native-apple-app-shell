import SwiftUI

public struct AppShellCommandReferenceItem: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var section: String
    public var shortcut: String?
    public var keywords: String

    public init(
        id: String,
        title: String,
        section: String,
        shortcut: String? = nil,
        keywords: String = ""
    ) {
        self.id = id
        self.title = title
        self.section = section
        self.shortcut = shortcut
        self.keywords = keywords
    }

    public var searchableText: String {
        "\(title) \(section) \(keywords) \(shortcutSearchText)"
            .lowercased()
    }

    private var shortcutSearchText: String {
        guard let shortcut else { return "" }
        return shortcut
            .replacingOccurrences(of: "⌘", with: " command cmd ")
            .replacingOccurrences(of: "⇧", with: " shift ")
            .replacingOccurrences(of: "⌥", with: " option alt ")
            .replacingOccurrences(of: "⌃", with: " control ctrl ")
            .replacingOccurrences(of: "?", with: " question slash shift ")
            .replacingOccurrences(of: "/", with: " slash ")
    }
}

public struct AppShellCommandReferenceSection: Identifiable, Equatable, Sendable {
    public var name: String
    public var items: [AppShellCommandReferenceItem]

    public init(name: String, items: [AppShellCommandReferenceItem]) {
        self.name = name
        self.items = items
    }

    public var id: String { name }
}

public enum AppShellCommandReferenceCatalog {
    public static func filter(
        _ items: [AppShellCommandReferenceItem],
        query: String,
        emptyLimit: Int = .max,
        resultLimit: Int = .max
    ) -> [AppShellCommandReferenceItem] {
        let terms = query
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else { return Array(items.prefix(emptyLimit)) }
        return items
            .filter { item in terms.allSatisfy { item.searchableText.contains($0) } }
            .prefix(resultLimit)
            .map { $0 }
    }

    public static func sections(
        for items: [AppShellCommandReferenceItem],
        query: String = "",
        preferredOrder: [String] = []
    ) -> [AppShellCommandReferenceSection] {
        let filtered = filter(items, query: query)
        let grouped = Dictionary(grouping: filtered, by: \.section)
        let orderedNames = preferredOrder + grouped.keys.sorted().filter { !preferredOrder.contains($0) }
        return orderedNames.compactMap { name in
            guard let sectionItems = grouped[name], !sectionItems.isEmpty else { return nil }
            return AppShellCommandReferenceSection(name: name, items: sectionItems)
        }
    }

    public static func spokenShortcut(_ shortcut: String) -> String {
        shortcut
            .replacingOccurrences(of: "⌘", with: "Command ")
            .replacingOccurrences(of: "⇧", with: "Shift ")
            .replacingOccurrences(of: "⌥", with: "Option ")
            .replacingOccurrences(of: "⌃", with: "Control ")
            .replacingOccurrences(of: "/", with: "Slash")
            .replacingOccurrences(of: "?", with: "Question Mark")
    }
}

@MainActor
public struct AppShellCommandReferenceView: View {
    public var title: String
    public var subtitle: String?
    public var items: [AppShellCommandReferenceItem]
    public var preferredSectionOrder: [String]
    public var searchPlaceholder: String
    public var doneTitle: String
    public var onDone: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    public init(
        title: String = "Keyboard Shortcuts",
        subtitle: String? = nil,
        items: [AppShellCommandReferenceItem],
        preferredSectionOrder: [String] = [],
        searchPlaceholder: String = "Search commands",
        doneTitle: String = "Done",
        onDone: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.preferredSectionOrder = preferredSectionOrder
        self.searchPlaceholder = searchPlaceholder
        self.doneTitle = doneTitle
        self.onDone = onDone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            search
                .padding(.horizontal, 20)
                .padding(.top, 14)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(section.items) { item in
                                commandRow(item)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 500, idealHeight: 620)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: "keyboard")
                    .font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(doneTitle) {
                if let onDone {
                    onDone()
                } else {
                    dismiss()
                }
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(searchPlaceholder, text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(searchPlaceholder)
        }
    }

    private var sections: [AppShellCommandReferenceSection] {
        AppShellCommandReferenceCatalog.sections(
            for: items,
            query: query,
            preferredOrder: preferredSectionOrder
        )
    }

    private func commandRow(_ item: AppShellCommandReferenceItem) -> some View {
        HStack(spacing: 10) {
            Text(item.title)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer(minLength: 16)
            if let shortcut = item.shortcut {
                AppShellShortcutBadge(text: shortcut)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(commandAccessibilityLabel(item))
    }

    private func commandAccessibilityLabel(_ item: AppShellCommandReferenceItem) -> String {
        if let shortcut = item.shortcut {
            return "\(item.title), \(AppShellCommandReferenceCatalog.spokenShortcut(shortcut))"
        }
        return item.title
    }
}

@MainActor
public struct AppShellShortcutBadge: View {
    public var text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary, lineWidth: 1))
            .accessibilityLabel(AppShellCommandReferenceCatalog.spokenShortcut(text))
    }
}
