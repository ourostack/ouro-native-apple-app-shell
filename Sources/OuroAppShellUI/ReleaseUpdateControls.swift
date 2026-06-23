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

    public init(
        state: ReleaseUpdateViewState,
        actions: ReleaseUpdateActions,
        labels: ReleaseUpdateActionLabels = ReleaseUpdateActionLabels(),
        showTitle: Bool = true,
        centered: Bool = false
    ) {
        self.state = state
        self.actions = actions
        self.labels = labels
        self.showTitle = showTitle
        self.centered = centered
    }

    public var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 8) {
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

            VStack(alignment: centered ? .center : .leading, spacing: 8) {
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
        Button {
            actions.checkForUpdates()
        } label: {
            Label(labels.check, systemImage: "arrow.clockwise")
        }
        .controlSize(.small)
        .disabled(state.kind == .checking)
        .accessibilityLabel("Check for updates")
    }

    @ViewBuilder
    private var reviewUpdateButton: some View {
        if state.canReviewUpdate, let reviewUpdate = actions.reviewUpdate {
            Button {
                reviewUpdate()
            } label: {
                Label(labels.review, systemImage: "arrow.down.circle")
            }
            .controlSize(.small)
            .disabled(state.kind == .installing)
            .accessibilityLabel("Review update")
        }
    }

    @ViewBuilder
    private var installAndRelaunchButton: some View {
        if state.canInstallUpdate, let installAndRelaunch = actions.installAndRelaunch {
            Button {
                installAndRelaunch()
            } label: {
                Label(labels.install, systemImage: "arrow.down.app.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(state.kind == .installing)
            .accessibilityLabel("Install and relaunch")
        }
    }

    @ViewBuilder
    private var openReleasePageButton: some View {
        if state.canOpenReleasePage, let openReleasePage = actions.openReleasePage {
            Button {
                openReleasePage()
            } label: {
                Label(labels.openRelease, systemImage: "safari")
            }
            .controlSize(.small)
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
            Text(kind.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
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
