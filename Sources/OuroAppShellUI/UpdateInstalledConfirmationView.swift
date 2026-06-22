import SwiftUI

@MainActor
public struct UpdateInstalledConfirmationView: View {
    public var appName: String
    public var version: String
    public var openAboutLabel: String
    public var onOpenAbout: () -> Void
    public var onDismiss: () -> Void

    public init(
        appName: String,
        version: String,
        openAboutLabel: String = "Open About",
        onOpenAbout: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.appName = appName
        self.version = version
        self.openAboutLabel = openAboutLabel
        self.onOpenAbout = onOpenAbout
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 26))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(appName) \(version) is installed")
                        .font(.system(size: 14, weight: .semibold))
                    Text("The latest version is now running on this Mac.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Button {
                    onOpenAbout()
                } label: {
                    Label(openAboutLabel, systemImage: "info.circle")
                }
                Button("Done") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(minWidth: 360)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(appName) \(version) is installed")
    }
}
