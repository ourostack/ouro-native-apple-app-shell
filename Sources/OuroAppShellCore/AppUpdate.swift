import Foundation

public struct AppUpdateManifest: Codable, Equatable, Sendable {
    public var appName: String
    public var bundleIdentifier: String
    public var version: String
    public var build: String
    public var archive: String
    public var sha256: String
    public var bytes: Int

    public init(
        appName: String,
        bundleIdentifier: String,
        version: String,
        build: String,
        archive: String,
        sha256: String,
        bytes: Int
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.build = build
        self.archive = archive
        self.sha256 = sha256
        self.bytes = bytes
    }
}

public struct AppUpdatePlan: Equatable, Sendable {
    public var version: String
    public var build: String?
    public var archiveURL: URL
    public var archiveName: String
    public var manifestURL: URL

    public init(version: String, build: String? = nil, archiveURL: URL, archiveName: String, manifestURL: URL) {
        self.version = version
        self.build = build
        self.archiveURL = archiveURL
        self.archiveName = archiveName
        self.manifestURL = manifestURL
    }
}

public enum ReleaseInstallCapability: String, Codable, CaseIterable, Equatable, Sendable {
    case none
    case reviewThenInstall
    case directInstallAndRelaunch
    case readyToRelaunch

    public var canInstallFromShellControl: Bool {
        switch self {
        case .directInstallAndRelaunch, .readyToRelaunch:
            return true
        case .none, .reviewThenInstall:
            return false
        }
    }

    public var requiresAppReviewPrompt: Bool {
        self == .reviewThenInstall
    }

    public var userFacingSummary: String {
        switch self {
        case .none:
            return "Updates can be checked, but this surface cannot install them."
        case .reviewThenInstall:
            return "Review update details in the app before installing."
        case .directInstallAndRelaunch:
            return "Install and relaunch directly from shell update controls."
        case .readyToRelaunch:
            return "Relaunch directly from shell update controls after staging completes."
        }
    }
}

public struct AppStagedUpdate: Codable, Equatable, Sendable {
    public var version: String
    public var archiveURL: URL
    public var appBundleURL: URL
    public var backupBundleURL: URL?

    public init(
        version: String,
        archiveURL: URL,
        appBundleURL: URL,
        backupBundleURL: URL? = nil
    ) {
        self.version = version
        self.archiveURL = archiveURL
        self.appBundleURL = appBundleURL
        self.backupBundleURL = backupBundleURL
    }
}

public enum AppUpdateApplyMode: String, Codable, Equatable, Sendable {
    case immediateRelaunch
    case onQuit
}

public struct AppUpdateApplyRequest: Codable, Equatable, Sendable {
    public var stagedUpdate: AppStagedUpdate
    public var mode: AppUpdateApplyMode

    public init(stagedUpdate: AppStagedUpdate, mode: AppUpdateApplyMode) {
        self.stagedUpdate = stagedUpdate
        self.mode = mode
    }
}

public enum AppUpdatePlanError: Error, Equatable, LocalizedError, Sendable {
    case notAnUpdate
    case missingArchiveAsset
    case missingManifestAsset
    case badAssetURL

    public var errorDescription: String? {
        switch self {
        case .notAnUpdate:
            return "No newer release is available to install."
        case .missingArchiveAsset:
            return "The release is missing a downloadable app archive (.zip)."
        case .missingManifestAsset:
            return "The release is missing its artifact manifest (.manifest.json)."
        case .badAssetURL:
            return "The release asset download URL was not valid."
        }
    }
}

public enum AppUpdatePlanner {
    public static func plan(from snapshot: ReleaseUpdateSnapshot, requireHTTPS: Bool = true) -> Result<AppUpdatePlan, AppUpdatePlanError> {
        guard snapshot.status == .updateAvailable, let version = snapshot.latestVersion else {
            return .failure(.notAnUpdate)
        }

        let assets = snapshot.installableAssets
        guard let archive = assets.first(where: { snapshot.assetNamingPolicy.isArchive($0.name) }) else {
            return .failure(.missingArchiveAsset)
        }
        guard let manifest = assets.first(where: { snapshot.assetNamingPolicy.isManifest($0.name) }) else {
            return .failure(.missingManifestAsset)
        }
        guard let archiveURL = validAssetURL(archive.downloadURL, requireHTTPS: requireHTTPS),
              let manifestURL = validAssetURL(manifest.downloadURL, requireHTTPS: requireHTTPS)
        else {
            return .failure(.badAssetURL)
        }

        return .success(
            AppUpdatePlan(
                version: version,
                build: snapshot.latestBuild,
                archiveURL: archiveURL,
                archiveName: archive.name,
                manifestURL: manifestURL
            )
        )
    }

    private static func validAssetURL(_ value: String, requireHTTPS: Bool) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              url.host != nil
        else {
            return nil
        }

        guard !requireHTTPS || scheme == "https" else {
            return nil
        }

        return url
    }
}

public enum AutoUpdatePolicy {
    public static func shouldCheck(
        now: Date,
        lastCheck: Date?,
        minimumInterval: TimeInterval,
        enabled: Bool
    ) -> Bool {
        guard enabled else {
            return false
        }
        guard let lastCheck else {
            return true
        }
        return now.timeIntervalSince(lastCheck) >= minimumInterval
    }
}

public enum AppUpdateVerification {
    public enum Failure: Error, Equatable, LocalizedError, Sendable {
        case archiveNameMismatch(expected: String, got: String)
        case sha256Mismatch(expected: String, got: String)
        case byteCountMismatch(expected: Int, got: Int)
        case bundleIdentifierMismatch(expected: String, got: String)
        case unreadableVersion(manifest: String, current: String)
        case notNewerThanCurrent(current: String, candidate: String)

        public var errorDescription: String? {
            switch self {
            case let .archiveNameMismatch(expected, got):
                return "Downloaded archive name \(got) did not match the manifest (\(expected))."
            case .sha256Mismatch:
                return "Downloaded archive failed its SHA-256 integrity check."
            case let .byteCountMismatch(expected, got):
                return "Downloaded archive size (\(got) bytes) did not match the manifest (\(expected) bytes)."
            case let .bundleIdentifierMismatch(expected, got):
                return "Update bundle identifier \(got) did not match this app (\(expected))."
            case let .unreadableVersion(manifest, current):
                return "Could not compare the update version (\(manifest)) to the current version (\(current))."
            case let .notNewerThanCurrent(current, candidate):
                return "Update version \(candidate) is not newer than the installed \(current)."
            }
        }
    }

    public static func verify(
        manifest: AppUpdateManifest,
        downloadedArchiveName: String,
        downloadedSHA256: String,
        downloadedBytes: Int,
        expectedBundleIdentifier: String,
        currentVersion: String,
        currentBuild: String? = nil,
        compareBuilds: Bool = true
    ) -> Failure? {
        guard downloadedArchiveName == manifest.archive else {
            return .archiveNameMismatch(expected: manifest.archive, got: downloadedArchiveName)
        }

        let expectedSHA = manifest.sha256.lowercased()
        let actualSHA = downloadedSHA256.lowercased()
        guard actualSHA == expectedSHA else {
            return .sha256Mismatch(expected: expectedSHA, got: actualSHA)
        }

        guard downloadedBytes == manifest.bytes else {
            return .byteCountMismatch(expected: manifest.bytes, got: downloadedBytes)
        }

        guard manifest.bundleIdentifier == expectedBundleIdentifier else {
            return .bundleIdentifierMismatch(expected: expectedBundleIdentifier, got: manifest.bundleIdentifier)
        }

        let candidate = ReleaseVersionIdentity(version: manifest.version, build: compareBuilds ? manifest.build : nil)
        let current = ReleaseVersionIdentity(version: currentVersion, build: compareBuilds ? currentBuild : nil)
        guard let isNewer = candidate.isNewer(than: current) else {
            return .unreadableVersion(manifest: manifest.version, current: currentVersion)
        }

        guard isNewer else {
            return .notNewerThanCurrent(current: label(for: current), candidate: label(for: candidate))
        }

        return nil
    }

    private static func label(for identity: ReleaseVersionIdentity) -> String {
        identity.build == nil ? identity.version : identity.display
    }
}
