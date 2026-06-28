import Foundation

public struct ReleaseUpdatePolicy: Codable, Equatable, Sendable {
    public var assetNamingPolicy: ReleaseAssetNamingPolicy
    public var includePrereleases: Bool

    public init(
        assetNamingPolicy: ReleaseAssetNamingPolicy = .simpleArchiveAndManifest(),
        includePrereleases: Bool = false
    ) {
        self.assetNamingPolicy = assetNamingPolicy
        self.includePrereleases = includePrereleases
    }

    public static func stable(
        assetNamingPolicy: ReleaseAssetNamingPolicy = .simpleArchiveAndManifest()
    ) -> ReleaseUpdatePolicy {
        ReleaseUpdatePolicy(assetNamingPolicy: assetNamingPolicy, includePrereleases: false)
    }

    public static func buildMatchedPrerelease(
        namePrefix: String,
        buildMarker: String = "-build."
    ) -> ReleaseUpdatePolicy {
        ReleaseUpdatePolicy(
            assetNamingPolicy: .buildMatchedArchiveAndManifest(
                namePrefix: namePrefix,
                buildMarker: buildMarker
            ),
            includePrereleases: true
        )
    }

    public static func workbench(namePrefix: String = "OuroWorkbench-") -> ReleaseUpdatePolicy {
        buildMatchedPrerelease(namePrefix: namePrefix, buildMarker: "-build.")
    }
}
