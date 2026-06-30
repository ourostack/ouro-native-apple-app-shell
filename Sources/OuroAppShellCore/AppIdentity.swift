import Foundation

public enum DistributionChannel: String, Codable, Equatable, Sendable {
    case directDownload
    case developerIDDirect
    case appStore

    public var descriptor: DistributionChannelDescriptor {
        switch self {
        case .directDownload:
            return DistributionChannelDescriptor(
                channel: self,
                displayName: "Direct download",
                supportsInAppInstall: true,
                requiresSignedInstaller: false
            )
        case .developerIDDirect:
            return DistributionChannelDescriptor(
                channel: self,
                displayName: "Developer ID direct download",
                supportsInAppInstall: true,
                requiresSignedInstaller: true
            )
        case .appStore:
            return DistributionChannelDescriptor(
                channel: self,
                displayName: "App Store",
                supportsInAppInstall: false,
                requiresSignedInstaller: true
            )
        }
    }
}

public struct DistributionChannelDescriptor: Codable, Equatable, Sendable {
    public var channel: DistributionChannel
    public var displayName: String
    public var supportsInAppInstall: Bool
    public var requiresSignedInstaller: Bool

    public init(
        channel: DistributionChannel,
        displayName: String,
        supportsInAppInstall: Bool,
        requiresSignedInstaller: Bool
    ) {
        self.channel = channel
        self.displayName = displayName
        self.supportsInAppInstall = supportsInAppInstall
        self.requiresSignedInstaller = requiresSignedInstaller
    }
}

public struct AppReleaseMetadata: Codable, Equatable, Sendable {
    public var appName: String
    public var version: String
    public var build: String?
    public var releaseDate: String?
    public var repository: String
    public var channel: DistributionChannel
    public var highlights: [String]
    public var shellRevision: String?

    public init(
        appName: String,
        version: String,
        build: String? = nil,
        releaseDate: String? = nil,
        repository: String,
        channel: DistributionChannel,
        highlights: [String] = [],
        shellRevision: String? = nil
    ) {
        self.appName = appName
        self.version = version
        self.build = build
        self.releaseDate = releaseDate
        self.repository = repository
        self.channel = channel
        self.highlights = highlights
        self.shellRevision = shellRevision
    }

    public var channelDescriptor: DistributionChannelDescriptor {
        channel.descriptor
    }

    public var versionLine: String {
        guard let build, !build.isEmpty else {
            return version
        }
        return "\(version) (\(build))"
    }
}

public struct AppShellIdentity: Codable, Equatable, Sendable {
    public var appName: String
    public var bundleIdentifier: String
    public var repository: String
    public var version: String
    public var build: String?
    public var userAgent: String
    public var distributionChannel: DistributionChannel
    public var releasePageURL: URL

    public init(
        appName: String,
        bundleIdentifier: String,
        repository: String,
        version: String,
        build: String? = nil,
        userAgent: String? = nil,
        distributionChannel: DistributionChannel = .directDownload,
        releasePageURL: URL? = nil
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.repository = repository
        self.version = version
        self.build = build
        self.userAgent = userAgent ?? Self.defaultUserAgent(appName: appName, version: version)
        self.distributionChannel = distributionChannel
        self.releasePageURL = releasePageURL ?? URL(string: "https://github.com/\(repository)/releases/latest")!
    }

    public var releasesAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=10")!
    }

    private static func defaultUserAgent(appName: String, version: String) -> String {
        let token = appName.filter { $0.isLetter || $0.isNumber }
        return "\(token.isEmpty ? "OuroApp" : token)/\(version)"
    }
}
