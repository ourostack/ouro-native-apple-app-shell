import Foundation
import OuroAppShellCore

public struct AppShellAboutModel: Equatable, Sendable {
    public var appName: String
    public var versionLine: String
    public var subtitle: String
    public var repositoryURL: URL?
    public var iconSystemName: String
    public var whatsNew: AppShellWhatsNewModel?

    public init(
        appName: String,
        versionLine: String,
        subtitle: String,
        repositoryURL: URL? = nil,
        iconSystemName: String,
        whatsNew: AppShellWhatsNewModel? = nil
    ) {
        self.appName = appName
        self.versionLine = versionLine
        self.subtitle = subtitle
        self.repositoryURL = repositoryURL
        self.iconSystemName = iconSystemName
        self.whatsNew = whatsNew
    }

    public init(
        identity: AppShellIdentity,
        versionDetail: String? = nil,
        subtitle: String,
        repositoryURL: URL? = nil,
        iconSystemName: String,
        whatsNew: AppShellWhatsNewModel? = nil
    ) {
        self.init(
            appName: identity.appName,
            versionLine: Self.versionLine(identity: identity, versionDetail: versionDetail),
            subtitle: subtitle,
            repositoryURL: repositoryURL ?? URL(string: "https://github.com/\(identity.repository)"),
            iconSystemName: iconSystemName,
            whatsNew: whatsNew
        )
    }

    public var accessibilityLabel: String {
        "About \(appName)"
    }

    public static func versionLine(identity: AppShellIdentity, versionDetail: String? = nil) -> String {
        let release = ReleaseVersionIdentity(version: identity.version, build: identity.build).display
        guard let versionDetail, !versionDetail.isEmpty else {
            return release
        }
        return "\(release) - \(versionDetail)"
    }
}

public struct AppShellWhatsNewModel: Equatable, Sendable {
    public var title: String
    public var releasedText: String?
    public var highlights: [String]
    public var releaseNotesPreview: String?

    public init(
        title: String,
        releasedText: String? = nil,
        highlights: [String],
        releaseNotesPreview: String? = nil
    ) {
        self.title = title
        self.releasedText = releasedText
        self.highlights = highlights
        self.releaseNotesPreview = releaseNotesPreview
    }

    public var hasVisibleContent: Bool {
        !highlights.isEmpty || !(releaseNotesPreview ?? "").isEmpty
    }
}
