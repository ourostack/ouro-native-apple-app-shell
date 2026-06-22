import Foundation

public enum DistributionChannel: String, Codable, Equatable, Sendable {
    case directDownload
    case developerIDDirect
    case appStore
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
