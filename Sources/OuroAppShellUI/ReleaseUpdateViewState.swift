import Foundation
import OuroAppShellCore

public enum ReleaseUpdateTone: String, CaseIterable, Equatable, Sendable {
    case neutral
    case success
    case attention
    case danger
}

public enum ReleaseUpdateStateKind: String, CaseIterable, Equatable, Sendable {
    case notChecked
    case checking
    case current
    case updateAvailable
    case installing
    case readyToRelaunch
    case installed
    case unavailable
    case failed

    public var label: String {
        switch self {
        case .notChecked:
            return "Not Checked"
        case .checking:
            return "Checking"
        case .current:
            return "Current"
        case .updateAvailable:
            return "Available"
        case .installing:
            return "Installing"
        case .readyToRelaunch:
            return "Ready"
        case .installed:
            return "Installed"
        case .unavailable:
            return "Unavailable"
        case .failed:
            return "Failed"
        }
    }

    public var tone: ReleaseUpdateTone {
        switch self {
        case .current, .installed:
            return .success
        case .updateAvailable, .readyToRelaunch:
            return .attention
        case .failed:
            return .danger
        case .notChecked, .checking, .installing, .unavailable:
            return .neutral
        }
    }

    public var showsProgress: Bool {
        self == .checking || self == .installing
    }
}

public struct ReleaseUpdateMetadataItem: Identifiable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var value: String

    public init(id: String? = nil, label: String, value: String) {
        self.id = id ?? "\(label):\(value)"
        self.label = label
        self.value = value
    }
}

public struct ReleaseUpdateViewState: Equatable, Sendable {
    public var kind: ReleaseUpdateStateKind
    public var statusLine: String
    public var metadata: [ReleaseUpdateMetadataItem]
    public var detail: String?
    public var warning: String?
    public var canReviewUpdate: Bool
    public var canInstallUpdate: Bool
    public var canOpenReleasePage: Bool

    public init(
        kind: ReleaseUpdateStateKind,
        statusLine: String,
        metadata: [ReleaseUpdateMetadataItem] = [],
        detail: String? = nil,
        warning: String? = nil,
        canReviewUpdate: Bool = false,
        canInstallUpdate: Bool = false,
        canOpenReleasePage: Bool = false
    ) {
        self.kind = kind
        self.statusLine = statusLine
        self.metadata = metadata
        self.detail = detail
        self.warning = warning
        self.canReviewUpdate = canReviewUpdate
        self.canInstallUpdate = canInstallUpdate
        self.canOpenReleasePage = canOpenReleasePage
    }

    public static func notChecked(channel: String = "Direct download") -> ReleaseUpdateViewState {
        ReleaseUpdateViewState(
            kind: .notChecked,
            statusLine: "Updates have not been checked yet.",
            metadata: [ReleaseUpdateMetadataItem(label: "Channel", value: channel)]
        )
    }

    public var hasPrimaryAction: Bool {
        canReviewUpdate || canInstallUpdate
    }

    public var displayDetail: String? {
        warning ?? detail
    }

    public static func from(
        snapshot: ReleaseUpdateSnapshot,
        installPlan: Result<AppUpdatePlan, AppUpdatePlanError>? = nil,
        channel: String = "Direct download"
    ) -> ReleaseUpdateViewState {
        switch snapshot.status {
        case .current:
            return ReleaseUpdateViewState(
                kind: .current,
                statusLine: snapshot.detail,
                metadata: metadata(from: snapshot, channel: channel),
                canOpenReleasePage: snapshot.htmlURL != nil
            )
        case .updateAvailable:
            let plan = installPlan ?? AppUpdatePlanner.plan(from: snapshot)
            let canInstall = plan.isSuccess
            return ReleaseUpdateViewState(
                kind: .updateAvailable,
                statusLine: snapshot.detail,
                metadata: metadata(from: snapshot, channel: channel),
                detail: canInstall ? "The archive and manifest are present." : plan.failureDescription,
                canReviewUpdate: true,
                canInstallUpdate: canInstall,
                canOpenReleasePage: snapshot.htmlURL != nil
            )
        case .unavailable:
            return ReleaseUpdateViewState(
                kind: .unavailable,
                statusLine: snapshot.detail,
                metadata: metadata(from: snapshot, channel: channel),
                canOpenReleasePage: snapshot.htmlURL != nil
            )
        }
    }

    private static func metadata(
        from snapshot: ReleaseUpdateSnapshot,
        channel: String
    ) -> [ReleaseUpdateMetadataItem] {
        var items = [
            ReleaseUpdateMetadataItem(label: "Current", value: snapshot.currentReleaseLabelForPrompt)
        ]
        if let latest = snapshot.latestReleaseLabelForPrompt {
            items.append(ReleaseUpdateMetadataItem(label: "Latest", value: latest))
        }
        items.append(ReleaseUpdateMetadataItem(label: "Channel", value: channel))
        return items
    }
}

private extension Result where Failure == AppUpdatePlanError {
    var isSuccess: Bool {
        guard case .success = self else {
            return false
        }
        return true
    }

    var failureDescription: String {
        guard case let .failure(error) = self else {
            return ""
        }
        return error.localizedDescription
    }
}

public struct ReleaseUpdateActionLabels: Equatable, Sendable {
    public var check: String
    public var review: String
    public var install: String
    public var openRelease: String

    public init(
        check: String = "Check for Updates...",
        review: String = "Review Update",
        install: String = "Install & Relaunch",
        openRelease: String = "View Release Notes"
    ) {
        self.check = check
        self.review = review
        self.install = install
        self.openRelease = openRelease
    }
}
