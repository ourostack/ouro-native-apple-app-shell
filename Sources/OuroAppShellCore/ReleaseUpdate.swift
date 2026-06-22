import Foundation

public enum ReleaseUpdateStatus: String, Codable, Equatable, Sendable {
    case current
    case updateAvailable
    case unavailable
}

public struct ReleaseUpdateAsset: Codable, Equatable, Sendable {
    public var name: String
    public var downloadURL: String
    public var size: Int

    public init(name: String, downloadURL: String, size: Int) {
        self.name = name
        self.downloadURL = downloadURL
        self.size = size
    }
}

public struct ReleaseUpdateSnapshot: Codable, Equatable, Sendable {
    public var status: ReleaseUpdateStatus
    public var currentVersion: String
    public var currentBuild: String?
    public var latestVersion: String?
    public var latestBuild: String?
    public var tagName: String?
    public var htmlURL: String?
    public var publishedAt: String?
    public var body: String?
    public var assets: [ReleaseUpdateAsset]
    public var assetNamingPolicy: ReleaseAssetNamingPolicy
    public var detail: String

    public init(
        status: ReleaseUpdateStatus,
        currentVersion: String,
        currentBuild: String? = nil,
        latestVersion: String?,
        latestBuild: String? = nil,
        tagName: String?,
        htmlURL: String?,
        publishedAt: String? = nil,
        body: String? = nil,
        assets: [ReleaseUpdateAsset],
        assetNamingPolicy: ReleaseAssetNamingPolicy = .simpleArchiveAndManifest(),
        detail: String
    ) {
        self.status = status
        self.currentVersion = currentVersion
        self.currentBuild = currentBuild
        self.latestVersion = latestVersion
        self.latestBuild = latestBuild
        self.tagName = tagName
        self.htmlURL = htmlURL
        self.publishedAt = publishedAt
        self.body = body
        self.assets = assets
        self.assetNamingPolicy = assetNamingPolicy
        self.detail = detail
    }

    public var installableAssets: [ReleaseUpdateAsset] {
        guard let latestVersion else {
            return []
        }

        return assets.filter {
            assetNamingPolicy.isInstallableAssetName($0.name, version: latestVersion, build: latestBuild)
        }
    }

    public var hasInstallableAssets: Bool {
        installableAssets.contains { assetNamingPolicy.isArchive($0.name) }
            && installableAssets.contains { assetNamingPolicy.isManifest($0.name) }
    }

    public var releaseLabel: String {
        latestVersion ?? currentVersion
    }

    public var currentReleaseLabel: String {
        ReleaseVersionIdentity(version: currentVersion, build: currentBuild).display
    }

    public var currentReleaseLabelForPrompt: String {
        ReleaseVersionIdentity(version: currentVersion, build: currentBuild).label
    }

    public var latestReleaseLabel: String? {
        guard let latestVersion else {
            return nil
        }
        return ReleaseVersionIdentity(version: latestVersion, build: latestBuild).display
    }

    public var latestReleaseLabelForPrompt: String? {
        guard let latestVersion else {
            return nil
        }
        return ReleaseVersionIdentity(version: latestVersion, build: latestBuild).label
    }
}

public struct ReleaseUpdateConfiguration: Equatable, Sendable {
    public var identity: AppShellIdentity
    public var releasePolicy: ReleaseUpdatePolicy
    public var releasesURL: URL
    public var timeout: TimeInterval

    public init(
        identity: AppShellIdentity,
        releasePolicy: ReleaseUpdatePolicy = .stable(),
        releasesURL: URL? = nil,
        timeout: TimeInterval = 10
    ) {
        self.identity = identity
        self.releasePolicy = releasePolicy
        self.releasesURL = releasesURL ?? identity.releasesAPIURL
        self.timeout = timeout
    }

    public var repository: String {
        identity.repository
    }

    public var currentVersion: String {
        identity.version
    }

    public var currentBuild: String? {
        identity.build
    }

    public var assetNamingPolicy: ReleaseAssetNamingPolicy {
        releasePolicy.assetNamingPolicy
    }

    public var includePrereleases: Bool {
        releasePolicy.includePrereleases
    }
}

public struct ReleaseUpdateChecker: Sendable {
    public var configuration: ReleaseUpdateConfiguration
    private let dataLoader: @Sendable (URLRequest) async throws -> Data

    public init(
        configuration: ReleaseUpdateConfiguration,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> Data = ReleaseUpdateChecker.defaultDataLoader
    ) {
        self.configuration = configuration
        self.dataLoader = dataLoader
    }

    public func check() async -> ReleaseUpdateSnapshot {
        do {
            let data = try await dataLoader(Self.request(for: configuration))
            return try Self.snapshot(from: data, configuration: configuration)
        } catch {
            return ReleaseUpdateSnapshot(
                status: .unavailable,
                currentVersion: configuration.currentVersion,
                currentBuild: configuration.currentBuild,
                latestVersion: nil,
                latestBuild: nil,
                tagName: nil,
                htmlURL: nil,
                assets: [],
                assetNamingPolicy: configuration.assetNamingPolicy,
                detail: "Release update check failed: \(error.localizedDescription)"
            )
        }
    }

    public static func request(for configuration: ReleaseUpdateConfiguration) -> URLRequest {
        var request = URLRequest(url: configuration.releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.identity.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = configuration.timeout
        return request
    }

    public static func snapshot(from data: Data, configuration: ReleaseUpdateConfiguration) throws -> ReleaseUpdateSnapshot {
        try snapshot(
            from: data,
            currentVersion: configuration.currentVersion,
            currentBuild: configuration.currentBuild,
            assetNamingPolicy: configuration.assetNamingPolicy,
            includePrereleases: configuration.includePrereleases
        )
    }

    public static func snapshot(
        from data: Data,
        currentVersion: String,
        currentBuild: String? = nil,
        assetNamingPolicy: ReleaseAssetNamingPolicy = .simpleArchiveAndManifest(),
        includePrereleases: Bool = false
    ) throws -> ReleaseUpdateSnapshot {
        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
        guard let latest = releases.first(where: { !$0.draft && (includePrereleases || !$0.prerelease) }) else {
            return ReleaseUpdateSnapshot(
                status: .unavailable,
                currentVersion: currentVersion,
                currentBuild: currentBuild,
                latestVersion: nil,
                latestBuild: nil,
                tagName: nil,
                htmlURL: nil,
                assets: [],
                assetNamingPolicy: assetNamingPolicy,
                detail: "No published release found."
            )
        }

        let latestVersion = version(fromTag: latest.tagName)
        let assetNames = latest.assets.map(\.name)
        let latestBuild = assetNamingPolicy.latestBuild(fromAssetNames: assetNames, version: latestVersion)
        let status = status(
            currentVersion: currentVersion,
            currentBuild: currentBuild,
            latestVersion: latestVersion,
            latestBuild: latestBuild
        )
        let assets = latest.assets.map {
            ReleaseUpdateAsset(name: $0.name, downloadURL: $0.browserDownloadURL, size: $0.size)
        }

        let detail: String
        switch status {
        case .updateAvailable:
            detail = "\(ReleaseVersionIdentity(version: latestVersion, build: latestBuild).display) is available."
        case .current:
            detail = "\(ReleaseVersionIdentity(version: currentVersion, build: currentBuild).display) is current."
        case .unavailable:
            detail = "Latest release \(latest.tagName) could not be compared to \(currentVersion)."
        }

        return ReleaseUpdateSnapshot(
            status: status,
            currentVersion: currentVersion,
            currentBuild: currentBuild,
            latestVersion: latestVersion,
            latestBuild: latestBuild,
            tagName: latest.tagName,
            htmlURL: latest.htmlURL,
            publishedAt: latest.publishedAt,
            body: latest.body,
            assets: assets,
            assetNamingPolicy: assetNamingPolicy,
            detail: detail
        )
    }

    public static func defaultDataLoader(request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ReleaseUpdateError.badResponse
        }
        return data
    }

    private static func status(
        currentVersion: String,
        currentBuild: String?,
        latestVersion: String,
        latestBuild: String?
    ) -> ReleaseUpdateStatus {
        let current = ReleaseVersionIdentity(version: currentVersion, build: currentBuild)
        let latest = ReleaseVersionIdentity(version: latestVersion, build: latestBuild)
        guard let isNewer = latest.isNewer(than: current) else {
            return .unavailable
        }
        return isNewer ? .updateAvailable : .current
    }

    private static func version(fromTag tagName: String) -> String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}

public enum ReleaseUpdateError: Error, Equatable, LocalizedError, Sendable {
    case badResponse

    public var errorDescription: String? {
        switch self {
        case .badResponse:
            return "GitHub Releases returned an unsuccessful response."
        }
    }
}

private struct GitHubRelease: Decodable {
    var tagName: String
    var htmlURL: String
    var publishedAt: String?
    var body: String?
    var draft: Bool
    var prerelease: Bool
    var assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case body
        case draft
        case prerelease
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    var name: String
    var browserDownloadURL: String
    var size: Int

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}
