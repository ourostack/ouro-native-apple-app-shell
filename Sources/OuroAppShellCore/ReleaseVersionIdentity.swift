import Foundation

public struct SemanticVersion: Comparable, Equatable, Sendable {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init?(_ value: String) {
        let core = value.split(separator: "-", maxSplits: 1).first.map(String.init) ?? value
        let parts = core.split(separator: ".")
        guard parts.count == 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2])
        else {
            return nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}

public struct ReleaseVersionIdentity: Codable, Equatable, Sendable {
    public var version: String
    public var build: String?

    public init(version: String, build: String? = nil) {
        self.version = version
        self.build = build
    }

    public var display: String {
        "Version \(label)"
    }

    public var label: String {
        guard let build, !build.isEmpty else {
            return version
        }
        return "\(version) (build \(build))"
    }

    public func isNewer(than current: ReleaseVersionIdentity) -> Bool? {
        guard let candidateVersion = SemanticVersion(version),
              let currentVersion = SemanticVersion(current.version)
        else {
            return nil
        }

        if candidateVersion != currentVersion {
            return candidateVersion > currentVersion
        }

        guard let candidateBuild = numericBuild,
              let currentBuild = current.numericBuild
        else {
            return false
        }

        return candidateBuild > currentBuild
    }

    private var numericBuild: Int? {
        guard let build else {
            return nil
        }
        return Int(build)
    }
}
