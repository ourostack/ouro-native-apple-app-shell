import OuroHX
import SwiftUI

@MainActor
public struct UpdateInstalledConfirmationView: View {
    public var appName: String
    public var version: String
    public var openAboutLabel: String
    public var openAboutSystemImage: String?
    public var dismissLabel: String
    public var onOpenAbout: () -> Void
    public var onDismiss: () -> Void

    public init(
        appName: String,
        version: String,
        openAboutLabel: String = "Open About",
        openAboutSystemImage: String? = "info.circle",
        dismissLabel: String = "Done",
        onOpenAbout: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.appName = appName
        self.version = version
        self.openAboutLabel = openAboutLabel
        self.openAboutSystemImage = openAboutSystemImage
        self.dismissLabel = dismissLabel
        self.onOpenAbout = onOpenAbout
        self.onDismiss = onDismiss
    }

    public var body: some View {
        OuroBanner(
            "\(appName) \(version) is installed",
            description: "The latest version is now running on this Mac.",
            tone: .success
        ) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                if let openAboutSystemImage {
                    OuroButton(openAboutLabel, systemImage: openAboutSystemImage, variant: .outline, size: .sm) {
                        onOpenAbout()
                    }
                } else {
                    OuroButton(openAboutLabel, variant: .outline, size: .sm) {
                        onOpenAbout()
                    }
                }
                OuroButton(dismissLabel, size: .sm) {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 360)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(appName) \(version) is installed")
    }
}
