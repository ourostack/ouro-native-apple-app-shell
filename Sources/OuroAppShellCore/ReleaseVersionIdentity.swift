import Foundation

public struct SemanticVersion: Comparable, Equatable, Sendable {
    public var major: Int
    public var minor: Int
    public var patch: Int
    public var prereleaseIdentifiers: [PrereleaseIdentifier]

    public enum PrereleaseIdentifier: Comparable, Equatable, Sendable {
        case numeric(Int)
        case text(String)

        public static func < (lhs: PrereleaseIdentifier, rhs: PrereleaseIdentifier) -> Bool {
            switch (lhs, rhs) {
            case let (.numeric(left), .numeric(right)):
                return left < right
            case (.numeric, .text):
                return true
            case (.text, .numeric):
                return false
            case let (.text(left), .text(right)):
                return left < right
            }
        }
    }

    public init?(_ value: String) {
        let metadataSplit = value.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        guard let versionAndPrerelease = metadataSplit.first, !versionAndPrerelease.isEmpty else {
            return nil
        }
        let components = versionAndPrerelease.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let core = components.first, !core.isEmpty else {
            return nil
        }
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2])
        else {
            return nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
        if components.count == 2 {
            let identifiers = components[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard !identifiers.isEmpty, identifiers.allSatisfy({ !$0.isEmpty }) else {
                return nil
            }
            var parsedIdentifiers: [PrereleaseIdentifier] = []
            for identifier in identifiers {
                if identifier.allSatisfy(\.isNumber) {
                    guard (identifier == "0" || !identifier.hasPrefix("0")),
                          let numeric = Int(identifier)
                    else {
                        return nil
                    }
                    parsedIdentifiers.append(.numeric(numeric))
                } else {
                    parsedIdentifiers.append(.text(identifier))
                }
            }
            prereleaseIdentifiers = parsedIdentifiers
        } else {
            prereleaseIdentifiers = []
        }
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }
        if lhs.prereleaseIdentifiers.isEmpty || rhs.prereleaseIdentifiers.isEmpty {
            return !lhs.prereleaseIdentifiers.isEmpty && rhs.prereleaseIdentifiers.isEmpty
        }
        for (left, right) in zip(lhs.prereleaseIdentifiers, rhs.prereleaseIdentifiers) {
            if left != right {
                return left < right
            }
        }
        return lhs.prereleaseIdentifiers.count < rhs.prereleaseIdentifiers.count
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
