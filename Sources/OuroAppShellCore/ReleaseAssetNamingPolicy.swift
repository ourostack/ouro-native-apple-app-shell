import Foundation

public struct ReleaseAssetNamingPolicy: Codable, Equatable, Sendable {
    public var archiveSuffix: String
    public var manifestSuffix: String
    public var versionedNamePrefix: String?
    public var buildMarker: String?
    public var requiresMatchingBuild: Bool

    public init(
        archiveSuffix: String = ".zip",
        manifestSuffix: String = ".manifest.json",
        versionedNamePrefix: String? = nil,
        buildMarker: String? = nil,
        requiresMatchingBuild: Bool = false
    ) {
        self.archiveSuffix = archiveSuffix
        self.manifestSuffix = manifestSuffix
        self.versionedNamePrefix = versionedNamePrefix
        self.buildMarker = buildMarker
        self.requiresMatchingBuild = requiresMatchingBuild
    }

    public static func simpleArchiveAndManifest(
        archiveSuffix: String = ".zip",
        manifestSuffix: String = ".manifest.json"
    ) -> ReleaseAssetNamingPolicy {
        ReleaseAssetNamingPolicy(archiveSuffix: archiveSuffix, manifestSuffix: manifestSuffix)
    }

    public static func versionedArchiveAndManifest(
        namePrefix: String,
        buildMarker: String? = nil,
        requiresMatchingBuild: Bool = false,
        archiveSuffix: String = ".zip",
        manifestSuffix: String = ".manifest.json"
    ) -> ReleaseAssetNamingPolicy {
        ReleaseAssetNamingPolicy(
            archiveSuffix: archiveSuffix,
            manifestSuffix: manifestSuffix,
            versionedNamePrefix: namePrefix,
            buildMarker: buildMarker,
            requiresMatchingBuild: requiresMatchingBuild
        )
    }

    public static func workbench(namePrefix: String = "OuroWorkbench-") -> ReleaseAssetNamingPolicy {
        versionedArchiveAndManifest(
            namePrefix: namePrefix,
            buildMarker: "-build.",
            requiresMatchingBuild: true
        )
    }

    public func isArchive(_ name: String) -> Bool {
        name.hasSuffix(archiveSuffix)
    }

    public func isManifest(_ name: String) -> Bool {
        name.hasSuffix(manifestSuffix)
    }

    public func isInstallableAssetName(_ name: String, version: String, build: String?) -> Bool {
        guard isArchive(name) || isManifest(name) else {
            return false
        }

        guard let versionedNamePrefix else {
            return true
        }

        let versionPrefix = "\(versionedNamePrefix)\(version)"
        guard name.hasPrefix(versionPrefix) else {
            return false
        }

        guard let buildMarker else {
            return true
        }

        let buildPrefix = "\(versionPrefix)\(buildMarker)"
        guard name.hasPrefix(buildPrefix) else {
            return false
        }

        guard requiresMatchingBuild, let build, !build.isEmpty else {
            return true
        }

        return name.hasPrefix("\(buildPrefix)\(build)-")
    }

    public func latestBuild(fromAssetNames names: [String], version: String) -> String? {
        guard let versionedNamePrefix, let buildMarker else {
            return nil
        }

        let marker = "\(versionedNamePrefix)\(version)\(buildMarker)"
        let builds = names.compactMap { name -> Int? in
            guard (isArchive(name) || isManifest(name)), name.hasPrefix(marker) else {
                return nil
            }

            let tail = name.dropFirst(marker.count)
            let digits = tail.prefix { $0.isNumber }
            guard !digits.isEmpty else {
                return nil
            }

            return Int(digits)
        }

        return builds.max().map(String.init)
    }
}
