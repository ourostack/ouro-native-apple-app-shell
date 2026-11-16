import OuroHX
import SwiftUI

@MainActor
public struct ReleaseUpdateActions {
    public var checkForUpdates: () -> Void
    public var reviewUpdate: (() -> Void)?
    public var installAndRelaunch: (() -> Void)?
    public var openReleasePage: (() -> Void)?

    public init(
        checkForUpdates: @escaping () -> Void,
        reviewUpdate: (() -> Void)? = nil,
        installAndRelaunch: (() -> Void)? = nil,
        openReleasePage: (() -> Void)? = nil
    ) {
        self.checkForUpdates = checkForUpdates
        self.reviewUpdate = reviewUpdate
        self.installAndRelaunch = installAndRelaunch
        self.openReleasePage = openReleasePage
    }
}

@MainActor
public struct ReleaseUpdateControls: View {
    public var state: ReleaseUpdateViewState
    public var actions: ReleaseUpdateActions
    public var labels: ReleaseUpdateActionLabels
    public var showTitle: Bool
    public var centered: Bool
    public var spacing: CGFloat

    public init(
        state: ReleaseUpdateViewState,
        actions: ReleaseUpdateActions,
        labels: ReleaseUpdateActionLabels = ReleaseUpdateActionLabels(),
        showTitle: Bool = true,
        centered: Bool = false,
        spacing: CGFloat = 8
    ) {
        self.state = state
        self.actions = actions
        self.labels = labels
        self.showTitle = showTitle
        self.centered = centered
        self.spacing = spacing
    }

    public var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: spacing) {
            if showTitle {
                HStack(spacing: 8) {
                    Label("Software Updates", systemImage: "arrow.down.app")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 8)
                    AppShellStatusPill(kind: state.kind)
                }
            } else {
                AppShellStatusPill(kind: state.kind)
            }

            HStack(spacing: 8) {
                Text(state.statusLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if state.kind.showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .fixedSize()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Update status")
            .accessibilityValue(state.statusLine)

            if !state.metadata.isEmpty {
                metadataRow
            }

            if let displayDetail = state.displayDetail {
                Text(displayDetail)
                    .font(.system(size: 11))
                    .foregroundStyle(state.warning == nil ? Color.secondary : Color.orange)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actionsRow
        }
        .frame(maxWidth: centered ? .infinity : nil, alignment: centered ? .center : .leading)
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            ForEach(state.metadata) { item in
                HStack(spacing: 4) {
                    Text(item.label)
                        .foregroundStyle(.tertiary)
                    Text(item.value)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private var actionsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                checkForUpdatesButton
                reviewUpdateButton
                installAndRelaunchButton
                openReleasePageButton
            }

            VStack(alignment: centered ? .center : .leading, spacing: spacing) {
                HStack(spacing: 8) {
                    checkForUpdatesButton
                    reviewUpdateButton
                }
                HStack(spacing: 8) {
                    installAndRelaunchButton
                    openReleasePageButton
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var checkForUpdatesButton: some View {
        OuroButton(labels.check, systemImage: "arrow.clockwise", variant: .outline, size: .sm) {
            actions.checkForUpdates()
        }
        .disabled(state.kind == .checking)
        .accessibilityLabel("Check for updates")
    }

    @ViewBuilder
    private var reviewUpdateButton: some View {
        if state.canReviewUpdate, let reviewUpdate = actions.reviewUpdate {
            OuroButton(labels.review, systemImage: "arrow.down.circle", variant: .outline, size: .sm) {
                reviewUpdate()
            }
            .disabled(state.kind == .installing)
            .accessibilityLabel("Review update")
        }
    }

    @ViewBuilder
    private var installAndRelaunchButton: some View {
        if state.canInstallUpdate, let installAndRelaunch = actions.installAndRelaunch {
            OuroButton(labels.installActionLabel(for: state.kind), systemImage: installActionSystemImage, variant: .solid, size: .sm) {
                installAndRelaunch()
            }
            .disabled(state.kind == .installing)
            .accessibilityLabel(labels.installActionAccessibilityLabel(for: state.kind))
        }
    }

    private var installActionSystemImage: String {
        state.kind == .readyToRelaunch ? "arrow.clockwise.circle.fill" : "arrow.down.app.fill"
    }

    @ViewBuilder
    private var openReleasePageButton: some View {
        if state.canOpenReleasePage, let openReleasePage = actions.openReleasePage {
            OuroButton(labels.openRelease, systemImage: "safari", variant: .outline, size: .sm) {
                openReleasePage()
            }
            .accessibilityLabel("Open release notes")
        }
    }
}

@MainActor
public struct AppShellStatusPill: View {
    public var kind: ReleaseUpdateStateKind

    public init(kind: ReleaseUpdateStateKind) {
        self.kind = kind
    }

    public var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            OuroBadge(kind.label, tone: kind.tone.ouroTone, variant: .soft)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Update state")
        .accessibilityValue(kind.label)
    }

    private var color: Color {
        switch kind.tone {
        case .neutral:
            return .secondary
        case .success:
            return .green
        case .attention:
            return .orange
        case .danger:
            return .red
        }
    }
}

extension ReleaseUpdateTone {
    var ouroTone: OuroTone {
        switch self {
        case .neutral:
            return .secondary
        case .success:
            return .success
        case .attention:
            return .warning
        case .danger:
            return .destructive
        }
    }
}
