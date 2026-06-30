import Foundation
@_exported import OuroAppShellCore

public struct OuroAppShellContract: Codable, Equatable, Sendable {
    public var identity: AppShellIdentity
    public var requiredSurfaces: [AppShellSurface]
    public var releaseUpdates: OuroAppShellReleaseUpdateContract?
    public var about: OuroAppShellAboutContract?
    public var commandReference: OuroAppShellCommandReferenceContract?
    public var commandManifest: OuroAppShellCommandSurfaceManifest?
    public var utilityWindows: [OuroAppShellUtilityWindowContract]
    public var settings: OuroAppShellSettingsContract?
    public var privacyDiagnostics: OuroAppShellPrivacyDiagnosticsContract?

    public init(
        identity: AppShellIdentity,
        requiredSurfaces: [AppShellSurface],
        releaseUpdates: OuroAppShellReleaseUpdateContract? = nil,
        about: OuroAppShellAboutContract? = nil,
        commandReference: OuroAppShellCommandReferenceContract? = nil,
        commandManifest: OuroAppShellCommandSurfaceManifest? = nil,
        utilityWindows: [OuroAppShellUtilityWindowContract] = [],
        settings: OuroAppShellSettingsContract? = nil,
        privacyDiagnostics: OuroAppShellPrivacyDiagnosticsContract? = nil
    ) {
        self.identity = identity
        self.requiredSurfaces = requiredSurfaces
        self.releaseUpdates = releaseUpdates
        self.about = about
        self.commandReference = commandReference
        self.commandManifest = commandManifest
        self.utilityWindows = utilityWindows
        self.settings = settings
        self.privacyDiagnostics = privacyDiagnostics
    }

    public var shellFirstRequiredSurfaces: [AppShellSurface] {
        requiredSurfaces.filter(AppShellBoundary.requiresShellFirstDesign(_:))
    }
}

public struct OuroAppShellReleaseUpdateContract: Codable, Equatable, Sendable {
    public var policy: ReleaseUpdatePolicy
    public var installCapability: ReleaseInstallCapability
    public var supportsReleasePage: Bool

    public var supportsInstallAndRelaunch: Bool {
        installCapability.canInstallFromShellControl
    }

    public init(
        policy: ReleaseUpdatePolicy,
        installCapability: ReleaseInstallCapability,
        supportsReleasePage: Bool
    ) {
        self.policy = policy
        self.installCapability = installCapability
        self.supportsReleasePage = supportsReleasePage
    }

    public init(
        policy: ReleaseUpdatePolicy,
        supportsInstallAndRelaunch: Bool,
        supportsReleasePage: Bool
    ) {
        self.init(
            policy: policy,
            installCapability: supportsInstallAndRelaunch ? .directInstallAndRelaunch : .none,
            supportsReleasePage: supportsReleasePage
        )
    }
}

public struct OuroAppShellAboutContract: Codable, Equatable, Sendable {
    public var subtitle: String
    public var repositoryURL: URL?

    public init(subtitle: String, repositoryURL: URL? = nil) {
        self.subtitle = subtitle
        self.repositoryURL = repositoryURL
    }
}

public struct OuroAppShellCommandReferenceContract: Codable, Equatable, Sendable {
    public var title: String
    public var commandCount: Int
    public var sections: [String]
    public var entryPoint: String

    public init(title: String, commandCount: Int, sections: [String], entryPoint: String) {
        self.title = title
        self.commandCount = commandCount
        self.sections = sections
        self.entryPoint = entryPoint
    }
}

public struct OuroAppShellCommandSurfaceManifest: Codable, Equatable, Sendable {
    public var commands: [OuroAppShellCommandSurface]

    public init(commands: [OuroAppShellCommandSurface]) {
        self.commands = commands
    }

    public var count: Int {
        commands.count
    }

    public var sections: [String] {
        var seen = Set<String>()
        return commands.compactMap { command in
            guard seen.insert(command.section).inserted else {
                return nil
            }
            return command.section
        }
    }
}

public struct OuroAppShellCommandSurface: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var section: String
    public var shortcut: String?
    public var menuPath: String?
    public var commandPaletteTitle: String?
    public var referenceTitle: String?

    public init(
        id: String,
        title: String,
        section: String,
        shortcut: String? = nil,
        menuPath: String? = nil,
        commandPaletteTitle: String? = nil,
        referenceTitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.section = section
        self.shortcut = shortcut
        self.menuPath = menuPath
        self.commandPaletteTitle = commandPaletteTitle
        self.referenceTitle = referenceTitle
    }
}

public struct OuroAppShellUtilityWindowContract: Codable, Equatable, Sendable {
    public var id: String
    public var surface: AppShellSurface
    public var title: String

    public init(id: String, surface: AppShellSurface, title: String) {
        self.id = id
        self.surface = surface
        self.title = title
    }
}

public struct OuroAppShellSettingsContract: Codable, Equatable, Sendable {
    public var entryPoint: String
    public var sharedSections: [OuroAppShellSettingsSectionContract]
    public var appOwnedSections: [String]

    public init(
        entryPoint: String,
        sharedSections: [OuroAppShellSettingsSectionContract] = [],
        appOwnedSections: [String] = []
    ) {
        self.entryPoint = entryPoint
        self.sharedSections = sharedSections
        self.appOwnedSections = appOwnedSections
    }
}

public struct OuroAppShellSettingsSectionContract: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case updates
        case telemetry
        case privacy
        case about
        case keyboardShortcuts
    }

    public var kind: Kind
    public var entryPoint: String

    public init(kind: Kind, entryPoint: String) {
        self.kind = kind
        self.entryPoint = entryPoint
    }

    public static func updates(entryPoint: String) -> Self {
        Self(kind: .updates, entryPoint: entryPoint)
    }

    public static func telemetry(entryPoint: String) -> Self {
        Self(kind: .telemetry, entryPoint: entryPoint)
    }

    public static func privacy(entryPoint: String) -> Self {
        Self(kind: .privacy, entryPoint: entryPoint)
    }

    public static func about(entryPoint: String) -> Self {
        Self(kind: .about, entryPoint: entryPoint)
    }

    public static func keyboardShortcuts(entryPoint: String) -> Self {
        Self(kind: .keyboardShortcuts, entryPoint: entryPoint)
    }
}

public struct OuroAppShellPrivacyDiagnosticsContract: Codable, Equatable, Sendable {
    public var telemetryConsentEntryPoint: String
    public var privacyDocumentURL: URL
    public var diagnosticsExportDisclosure: String
    public var supportBundleContents: [String]
    public var redactionGuarantees: [String]

    public init(
        telemetryConsentEntryPoint: String,
        privacyDocumentURL: URL,
        diagnosticsExportDisclosure: String,
        supportBundleContents: [String],
        redactionGuarantees: [String]
    ) {
        self.telemetryConsentEntryPoint = telemetryConsentEntryPoint
        self.privacyDocumentURL = privacyDocumentURL
        self.diagnosticsExportDisclosure = diagnosticsExportDisclosure
        self.supportBundleContents = supportBundleContents
        self.redactionGuarantees = redactionGuarantees
    }
}

public struct OuroAppShellContractIssue: Codable, Equatable, Sendable {
    public enum Code: String, Codable, Equatable, Sendable {
        case emptyIdentityField
        case duplicateRequiredSurface
        case appOwnedSurfaceRequired
        case missingReleaseUpdates
        case missingAbout
        case missingCommandReference
        case missingUtilityWindows
        case missingSettings
        case emptyReleasePolicy
        case emptyAboutSubtitle
        case emptyCommandReferenceTitle
        case emptyCommandReference
        case emptyCommandReferenceSections
        case emptyCommandReferenceEntryPoint
        case missingCommandManifest
        case emptyCommandID
        case emptyCommandTitle
        case emptyCommandSection
        case duplicateCommandID
        case commandManifestCountMismatch
        case commandManifestSectionsMismatch
        case emptyUtilityWindowID
        case appOwnedUtilityWindowSurface
        case emptyUtilityWindowTitle
        case emptySettingsEntryPoint
        case emptySharedSettingsSectionEntryPoint
        case emptyAppOwnedSettingsSection
        case emptyTelemetryConsentEntryPoint
        case emptyDiagnosticsExportDisclosure
        case emptySupportBundleContent
        case emptyRedactionGuarantee
    }

    public var code: Code
    public var message: String
    public var surface: AppShellSurface?

    public init(code: Code, message: String, surface: AppShellSurface? = nil) {
        self.code = code
        self.message = message
        self.surface = surface
    }
}

extension OuroAppShellContractIssue: CustomStringConvertible {
    public var description: String {
        if let surface {
            return "\(code.rawValue)(\(surface.rawValue)): \(message)"
        }
        return "\(code.rawValue): \(message)"
    }
}

public enum OuroAppShellContractValidator {
    public static func validate(_ contract: OuroAppShellContract) -> [OuroAppShellContractIssue] {
        var issues: [OuroAppShellContractIssue] = []

        if hasEmptyIdentityField(contract.identity) {
            issues.append(.init(code: .emptyIdentityField, message: "Identity fields must not be empty."))
        }

        issues.append(contentsOf: duplicateSurfaceIssues(contract.requiredSurfaces))
        issues.append(contentsOf: appOwnedRequiredSurfaceIssues(contract.requiredSurfaces))
        issues.append(contentsOf: missingDescriptorIssues(contract))
        issues.append(contentsOf: descriptorIssues(contract))

        return issues
    }

    private static func hasEmptyIdentityField(_ identity: AppShellIdentity) -> Bool {
        [
            identity.appName,
            identity.bundleIdentifier,
            identity.repository,
            identity.version
        ].contains { trimmed($0).isEmpty }
    }

    private static func duplicateSurfaceIssues(_ surfaces: [AppShellSurface]) -> [OuroAppShellContractIssue] {
        var seen = Set<AppShellSurface>()
        var duplicates = Set<AppShellSurface>()

        for surface in surfaces where !seen.insert(surface).inserted {
            duplicates.insert(surface)
        }

        return surfaces.compactMap { surface in
            duplicates.remove(surface).map { duplicate in
                OuroAppShellContractIssue(
                    code: .duplicateRequiredSurface,
                    message: "Required surfaces must be unique.",
                    surface: duplicate
                )
            }
        }
    }

    private static func appOwnedRequiredSurfaceIssues(_ surfaces: [AppShellSurface]) -> [OuroAppShellContractIssue] {
        surfaces.compactMap { surface in
            guard AppShellBoundary.owner(for: surface).owner == .app else {
                return nil
            }
            return OuroAppShellContractIssue(
                code: .appOwnedSurfaceRequired,
                message: "App-owned surfaces must not be declared as shell-required surfaces.",
                surface: surface
            )
        }
    }

    private static func missingDescriptorIssues(_ contract: OuroAppShellContract) -> [OuroAppShellContractIssue] {
        var issues: [OuroAppShellContractIssue] = []
        let required = Set(contract.requiredSurfaces)

        if required.contains(.releaseUpdates), contract.releaseUpdates == nil {
            issues.append(.init(code: .missingReleaseUpdates, message: "Release updates require a release update contract.", surface: .releaseUpdates))
        }
        if required.contains(.about), contract.about == nil {
            issues.append(.init(code: .missingAbout, message: "About requires an about contract.", surface: .about))
        }
        if required.contains(.keyboardShortcuts), contract.commandReference == nil {
            issues.append(.init(code: .missingCommandReference, message: "Keyboard shortcuts require a command reference contract.", surface: .keyboardShortcuts))
        }
        if required.contains(.windowChrome), contract.utilityWindows.isEmpty {
            issues.append(.init(code: .missingUtilityWindows, message: "Window chrome requires at least one utility window contract.", surface: .windowChrome))
        }
        if required.contains(.settings), contract.settings == nil {
            issues.append(.init(code: .missingSettings, message: "Settings requires a settings contract.", surface: .settings))
        }

        return issues
    }

    private static func descriptorIssues(_ contract: OuroAppShellContract) -> [OuroAppShellContractIssue] {
        var issues: [OuroAppShellContractIssue] = []

        if let releaseUpdates = contract.releaseUpdates, releaseUpdates.policy.assetNamingPolicy.archiveSuffix.isEmpty || releaseUpdates.policy.assetNamingPolicy.manifestSuffix.isEmpty {
            issues.append(.init(code: .emptyReleasePolicy, message: "Release update asset suffixes must not be empty.", surface: .releaseUpdates))
        }
        if let about = contract.about, trimmed(about.subtitle).isEmpty {
            issues.append(.init(code: .emptyAboutSubtitle, message: "About subtitle must not be empty.", surface: .about))
        }
        if let commandReference = contract.commandReference {
            issues.append(contentsOf: commandReferenceIssues(commandReference))
        }
        if let commandManifest = contract.commandManifest {
            issues.append(contentsOf: commandManifestIssues(commandManifest, commandReference: contract.commandReference))
        }
        issues.append(contentsOf: utilityWindowIssues(contract.utilityWindows))
        if let settings = contract.settings, trimmed(settings.entryPoint).isEmpty {
            issues.append(.init(code: .emptySettingsEntryPoint, message: "Settings entry point must not be empty.", surface: .settings))
        }
        if let settings = contract.settings {
            issues.append(contentsOf: settingsIssues(settings))
        }
        if let privacyDiagnostics = contract.privacyDiagnostics {
            issues.append(contentsOf: privacyDiagnosticsIssues(privacyDiagnostics))
        }

        return issues
    }

    private static func commandReferenceIssues(_ commandReference: OuroAppShellCommandReferenceContract) -> [OuroAppShellContractIssue] {
        var issues: [OuroAppShellContractIssue] = []

        if trimmed(commandReference.title).isEmpty {
            issues.append(.init(code: .emptyCommandReferenceTitle, message: "Command reference title must not be empty.", surface: .keyboardShortcuts))
        }
        if commandReference.commandCount <= 0 {
            issues.append(.init(code: .emptyCommandReference, message: "Command reference must declare at least one command.", surface: .keyboardShortcuts))
        }
        if commandReference.sections.allSatisfy({ trimmed($0).isEmpty }) {
            issues.append(.init(code: .emptyCommandReferenceSections, message: "Command reference must declare at least one named section.", surface: .keyboardShortcuts))
        }
        if trimmed(commandReference.entryPoint).isEmpty {
            issues.append(.init(code: .emptyCommandReferenceEntryPoint, message: "Command reference entry point must not be empty.", surface: .keyboardShortcuts))
        }

        return issues
    }

    private static func commandManifestIssues(
        _ manifest: OuroAppShellCommandSurfaceManifest,
        commandReference: OuroAppShellCommandReferenceContract?
    ) -> [OuroAppShellContractIssue] {
        var issues: [OuroAppShellContractIssue] = []
        var seen = Set<String>()
        var duplicateIDs = Set<String>()

        for command in manifest.commands {
            if trimmed(command.id).isEmpty {
                issues.append(.init(code: .emptyCommandID, message: "Command manifest items must have ids.", surface: .keyboardShortcuts))
            } else if !seen.insert(command.id).inserted {
                duplicateIDs.insert(command.id)
            }
            if trimmed(command.title).isEmpty {
                issues.append(.init(code: .emptyCommandTitle, message: "Command manifest items must have titles.", surface: .keyboardShortcuts))
            }
            if trimmed(command.section).isEmpty {
                issues.append(.init(code: .emptyCommandSection, message: "Command manifest items must have sections.", surface: .keyboardShortcuts))
            }
        }

        for duplicateID in duplicateIDs.sorted() {
            issues.append(.init(code: .duplicateCommandID, message: "Command manifest id is duplicated: \(duplicateID).", surface: .keyboardShortcuts))
        }

        if let commandReference {
            if commandReference.commandCount != manifest.count {
                issues.append(.init(code: .commandManifestCountMismatch, message: "Command reference count must match the command manifest.", surface: .keyboardShortcuts))
            }
            let manifestSections = manifest.sections
            let representedReferenceSections = commandReference.sections.filter { manifestSections.contains($0) }
            if representedReferenceSections != manifestSections {
                issues.append(.init(code: .commandManifestSectionsMismatch, message: "Command reference sections must match the command manifest.", surface: .keyboardShortcuts))
            }
        }

        return issues
    }

    private static func utilityWindowIssues(_ utilityWindows: [OuroAppShellUtilityWindowContract]) -> [OuroAppShellContractIssue] {
        utilityWindows.flatMap { window -> [OuroAppShellContractIssue] in
            var issues: [OuroAppShellContractIssue] = []
            if trimmed(window.id).isEmpty {
                issues.append(.init(code: .emptyUtilityWindowID, message: "Utility window id must not be empty.", surface: window.surface))
            }
            if AppShellBoundary.owner(for: window.surface).owner == .app {
                issues.append(.init(code: .appOwnedUtilityWindowSurface, message: "Utility windows must describe shell or adapter surfaces.", surface: window.surface))
            }
            if trimmed(window.title).isEmpty {
                issues.append(.init(code: .emptyUtilityWindowTitle, message: "Utility window title must not be empty.", surface: window.surface))
            }
            return issues
        }
    }

    private static func settingsIssues(_ settings: OuroAppShellSettingsContract) -> [OuroAppShellContractIssue] {
        var issues: [OuroAppShellContractIssue] = []

        for section in settings.sharedSections where trimmed(section.entryPoint).isEmpty {
            issues.append(.init(code: .emptySharedSettingsSectionEntryPoint, message: "Shared settings section entry points must not be empty.", surface: .settings))
        }
        for section in settings.appOwnedSections where trimmed(section).isEmpty {
            issues.append(.init(code: .emptyAppOwnedSettingsSection, message: "App-owned settings section names must not be empty.", surface: .settings))
        }

        return issues
    }

    private static func privacyDiagnosticsIssues(_ privacyDiagnostics: OuroAppShellPrivacyDiagnosticsContract) -> [OuroAppShellContractIssue] {
        var issues: [OuroAppShellContractIssue] = []

        if trimmed(privacyDiagnostics.telemetryConsentEntryPoint).isEmpty {
            issues.append(.init(code: .emptyTelemetryConsentEntryPoint, message: "Telemetry consent entry point must not be empty.", surface: .telemetry))
        }
        if trimmed(privacyDiagnostics.diagnosticsExportDisclosure).isEmpty {
            issues.append(.init(code: .emptyDiagnosticsExportDisclosure, message: "Diagnostics export disclosure must not be empty.", surface: .telemetry))
        }
        for content in privacyDiagnostics.supportBundleContents where trimmed(content).isEmpty {
            issues.append(.init(code: .emptySupportBundleContent, message: "Support bundle content descriptions must not be empty.", surface: .telemetry))
        }
        for guarantee in privacyDiagnostics.redactionGuarantees where trimmed(guarantee).isEmpty {
            issues.append(.init(code: .emptyRedactionGuarantee, message: "Redaction guarantees must not be empty.", surface: .telemetry))
        }

        return issues
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
