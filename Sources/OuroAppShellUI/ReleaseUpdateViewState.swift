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
                detail: plan.displayDetail,
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

    public static func from(presentation: ReleaseUpdatePresentationInput) -> ReleaseUpdateViewState {
        let channel = presentation.channel.descriptor.displayName
        if presentation.isChecking {
            return ReleaseUpdateViewState(
                kind: .checking,
                statusLine: "Checking for updates...",
                metadata: channelMetadata(channel)
            )
        }
        if presentation.isInstalling {
            return ReleaseUpdateViewState(
                kind: .installing,
                statusLine: "Installing update...",
                metadata: channelMetadata(channel, latest: presentation.stagedUpdateVersion),
                detail: presentation.installStatus
            )
        }
        if let installError = presentation.installError {
            return ReleaseUpdateViewState(
                kind: .failed,
                statusLine: "Install failed.",
                metadata: metadata(snapshot: presentation.snapshot, channel: channel, stagedUpdateVersion: presentation.stagedUpdateVersion),
                warning: installError,
                canReviewUpdate: presentation.canReviewUpdate,
                canOpenReleasePage: presentation.canOpenReleasePage
            )
        }
        if let stagedUpdateVersion = presentation.stagedUpdateVersion {
            return ReleaseUpdateViewState(
                kind: .readyToRelaunch,
                statusLine: "Update \(stagedUpdateVersion) is downloaded and ready to install.",
                metadata: channelMetadata(channel, latest: stagedUpdateVersion),
                canReviewUpdate: presentation.canReviewUpdate,
                canInstallUpdate: presentation.installCapability.canInstallFromShellControl,
                canOpenReleasePage: presentation.canOpenReleasePage
            )
        }
        if let recentlyInstalledVersion = presentation.recentlyInstalledVersion {
            return ReleaseUpdateViewState(
                kind: .installed,
                statusLine: "Updated to \(recentlyInstalledVersion) on this launch.",
                metadata: channelMetadata(channel, latest: recentlyInstalledVersion),
                canOpenReleasePage: presentation.canOpenReleasePage
            )
        }
        guard let snapshot = presentation.snapshot else {
            return ReleaseUpdateViewState(
                kind: .notChecked,
                statusLine: "Updates have not been checked yet.",
                metadata: channelMetadata(channel)
            )
        }

        var state = ReleaseUpdateViewState.from(
            snapshot: snapshot,
            installPlan: presentation.installPlan,
            channel: channel
        )
        state.canReviewUpdate = presentation.canReviewUpdate
        state.canInstallUpdate = state.canInstallUpdate && presentation.installCapability.canInstallFromShellControl
        state.canOpenReleasePage = presentation.canOpenReleasePage
        return state
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
        items.append(ReleaseUpdateMetadataItem(id: "channel", label: "Channel", value: channel))
        return items
    }

    private static func metadata(
        snapshot: ReleaseUpdateSnapshot?,
        channel: String,
        stagedUpdateVersion: String?
    ) -> [ReleaseUpdateMetadataItem] {
        guard let snapshot else {
            return channelMetadata(channel, latest: stagedUpdateVersion)
        }
        return metadata(from: snapshot, channel: channel)
    }

    private static func channelMetadata(_ channel: String, latest: String? = nil) -> [ReleaseUpdateMetadataItem] {
        var items: [ReleaseUpdateMetadataItem] = []
        if let latest {
            items.append(ReleaseUpdateMetadataItem(id: "latest", label: "Latest", value: latest))
        }
        items.append(ReleaseUpdateMetadataItem(id: "channel", label: "Channel", value: channel))
        return items
    }
}

public struct ReleaseUpdatePresentationInput: Equatable, Sendable {
    public var snapshot: ReleaseUpdateSnapshot?
    public var channel: DistributionChannel
    public var installCapability: ReleaseInstallCapability
    public var isChecking: Bool
    public var isInstalling: Bool
    public var installStatus: String?
    public var installError: String?
    public var stagedUpdateVersion: String?
    public var recentlyInstalledVersion: String?
    public var installPlan: Result<AppUpdatePlan, AppUpdatePlanError>?

    public init(
        snapshot: ReleaseUpdateSnapshot?,
        channel: DistributionChannel,
        installCapability: ReleaseInstallCapability,
        isChecking: Bool = false,
        isInstalling: Bool = false,
        installStatus: String? = nil,
        installError: String? = nil,
        stagedUpdateVersion: String? = nil,
        recentlyInstalledVersion: String? = nil,
        installPlan: Result<AppUpdatePlan, AppUpdatePlanError>? = nil
    ) {
        self.snapshot = snapshot
        self.channel = channel
        self.installCapability = installCapability
        self.isChecking = isChecking
        self.isInstalling = isInstalling
        self.installStatus = installStatus
        self.installError = installError
        self.stagedUpdateVersion = stagedUpdateVersion
        self.recentlyInstalledVersion = recentlyInstalledVersion
        self.installPlan = installPlan
    }

    public var canReviewUpdate: Bool {
        if isChecking {
            return false
        }
        if stagedUpdateVersion != nil {
            return installCapability.requiresAppReviewPrompt
        }
        return snapshot?.status == .updateAvailable
    }

    public var canOpenReleasePage: Bool {
        !isChecking && snapshot?.htmlURL != nil
    }
}

private extension Result where Failure == AppUpdatePlanError {
    var isSuccess: Bool {
        guard case .success = self else {
            return false
        }
        return true
    }

    var displayDetail: String {
        switch self {
        case .success:
            return "The archive and manifest are present."
        case let .failure(error):
            return error.localizedDescription
        }
    }
}

public struct ReleaseUpdateActionLabels: Equatable, Sendable {
    public var check: String
    public var review: String
    public var install: String
    public var relaunch: String
    public var openRelease: String

    public init(
        check: String = "Check for Updates...",
        review: String = "Review Update",
        install: String = "Install & Relaunch",
        relaunch: String = "Relaunch to Update",
        openRelease: String = "View Release Notes"
    ) {
        self.check = check
        self.review = review
        self.install = install
        self.relaunch = relaunch
        self.openRelease = openRelease
    }

    public func installActionLabel(for kind: ReleaseUpdateStateKind) -> String {
        kind == .readyToRelaunch ? relaunch : install
    }

    public func installActionAccessibilityLabel(for kind: ReleaseUpdateStateKind) -> String {
        kind == .readyToRelaunch ? "Relaunch to update" : "Install and relaunch"
    }
}
