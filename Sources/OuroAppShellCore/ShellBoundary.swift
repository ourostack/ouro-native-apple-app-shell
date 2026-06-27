public enum AppShellBoundaryOwner: String, Codable, Equatable, Sendable {
    case shell
    case app
    case adapter
}

public enum AppShellSurface: String, Codable, CaseIterable, Equatable, Sendable {
    case appIdentity
    case releaseUpdates
    case about
    case keyboardShortcuts
    case settings
    case windowChrome
    case telemetry
    case documentEditing
    case domainWorkflow
}

public struct AppShellBoundaryDecision: Codable, Equatable, Sendable {
    public var surface: AppShellSurface
    public var owner: AppShellBoundaryOwner
    public var reason: String

    public init(surface: AppShellSurface, owner: AppShellBoundaryOwner, reason: String) {
        self.surface = surface
        self.owner = owner
        self.reason = reason
    }
}

public enum AppShellBoundary {
    public static func owner(for surface: AppShellSurface) -> AppShellBoundaryDecision {
        switch surface {
        case .appIdentity:
            return .init(surface: surface, owner: .shell, reason: "Identity/version/channel metadata is shared across native Ouro apps.")
        case .releaseUpdates:
            return .init(surface: surface, owner: .shell, reason: "Release checking, update presentation, and install policy must stay consistent across native Ouro apps.")
        case .about:
            return .init(surface: surface, owner: .shell, reason: "About and What's New chrome is shared; apps provide only identity, copy, and actions.")
        case .keyboardShortcuts:
            return .init(surface: surface, owner: .shell, reason: "Shortcut discovery should use a common native command-reference surface.")
        case .settings:
            return .init(surface: surface, owner: .adapter, reason: "Settings chrome is shared, while each app still owns domain-specific preferences.")
        case .windowChrome:
            return .init(surface: surface, owner: .shell, reason: "Reusable utility-window presentation belongs in the shell; content remains app-owned.")
        case .telemetry:
            return .init(surface: surface, owner: .adapter, reason: "Telemetry consent and common event shape should be shared, while event meaning is app-specific.")
        case .documentEditing:
            return .init(surface: surface, owner: .app, reason: "Document/editor behavior is Ouro MD domain logic.")
        case .domainWorkflow:
            return .init(surface: surface, owner: .app, reason: "Agent/session/workflow behavior is Workbench domain logic.")
        }
    }

    public static func requiresShellFirstDesign(_ surface: AppShellSurface) -> Bool {
        let owner = owner(for: surface).owner
        return owner == .shell || owner == .adapter
    }
}
