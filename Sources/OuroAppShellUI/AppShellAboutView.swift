import SwiftUI

@MainActor
public struct AppShellAboutActions {
    public var openRepository: (() -> Void)?
    public var copyVersion: (() -> Void)?
    public var dismiss: (() -> Void)?

    public init(
        openRepository: (() -> Void)? = nil,
        copyVersion: (() -> Void)? = nil,
        dismiss: (() -> Void)? = nil
    ) {
        self.openRepository = openRepository
        self.copyVersion = copyVersion
        self.dismiss = dismiss
    }
}

@MainActor
public struct AppShellAboutView: View {
    public var model: AppShellAboutModel
    public var updateState: ReleaseUpdateViewState?
    public var updateActions: ReleaseUpdateActions?
    public var aboutActions: AppShellAboutActions
    @State private var copiedVersion = false

    public init(
        model: AppShellAboutModel,
        updateState: ReleaseUpdateViewState? = nil,
        updateActions: ReleaseUpdateActions? = nil,
        aboutActions: AppShellAboutActions = AppShellAboutActions()
    ) {
        self.model = model
        self.updateState = updateState
        self.updateActions = updateActions
        self.aboutActions = aboutActions
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let updateState, let updateActions {
                ReleaseUpdateControls(state: updateState, actions: updateActions, showTitle: true)
            }

            if let whatsNew = model.whatsNew, whatsNew.hasVisibleContent {
                AppShellWhatsNewView(model: whatsNew)
            }

            Spacer(minLength: 0)

            footer
        }
        .padding(20)
        .frame(minWidth: 460, idealWidth: 520, maxWidth: 560, minHeight: 360, idealHeight: 500)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.accessibilityLabel)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: model.iconSystemName)
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.appName)
                    .font(.title2.weight(.semibold))
                Text(model.versionLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .textSelection(.enabled)
                Text(model.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if aboutActions.openRepository != nil || model.repositoryURL != nil {
                Button {
                    aboutActions.openRepository?()
                } label: {
                    Label("Open Repo", systemImage: "arrow.up.right.square")
                }
                .disabled(aboutActions.openRepository == nil)
            }

            if let copyVersion = aboutActions.copyVersion {
                Button {
                    copyVersion()
                    copiedVersion = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        copiedVersion = false
                    }
                } label: {
                    Label(copiedVersion ? "Copied" : "Copy Version", systemImage: copiedVersion ? "checkmark" : "doc.on.doc")
                }
            }

            Spacer(minLength: 0)

            if let dismiss = aboutActions.dismiss {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

@MainActor
public struct AppShellWhatsNewView: View {
    public var model: AppShellWhatsNewModel

    public init(model: AppShellWhatsNewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(model.title, systemImage: "sparkles")
                .font(.system(size: 13, weight: .semibold))

            if let releasedText = model.releasedText {
                Text(releasedText)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            if !model.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(model.highlights, id: \.self) { highlight in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("-")
                                .foregroundStyle(.secondary)
                            Text(highlight)
                        }
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            if let notes = model.releaseNotesPreview, !notes.isEmpty {
                Divider()
                Text(notes)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
        }
    }
}
