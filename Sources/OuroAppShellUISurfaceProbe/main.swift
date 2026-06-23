import AppKit
import Foundation
import SwiftUI
import OuroAppShellCore
import OuroAppShellUI

@main
struct OuroAppShellUISurfaceProbe {
    @MainActor
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)

        do {
            try SurfaceProbe().run()
            print("OuroAppShell UI surface probe: ok")
        } catch {
            fputs("OuroAppShell UI surface probe failed: \(error)\n", stderr)
            exit(1)
        }
    }
}

@MainActor
private struct SurfaceProbe {
    func run() throws {
        let basicActions = ReleaseUpdateActions(checkForUpdates: {})
        let fullActions = ReleaseUpdateActions(
            checkForUpdates: {},
            reviewUpdate: {},
            installAndRelaunch: {},
            openReleasePage: {}
        )
        let currentState = ReleaseUpdateViewState.current
        let availableState = try updateAvailableState()

        try measure(
            spec: SurfaceSpec(
                name: "about-current",
                width: 560,
                height: 540,
                expectedWidth: 500...540,
                expectedHeight: 470...530,
                minimumInkRatio: 0.055,
                semanticText: aboutSemantics(
                    model: aboutModel,
                    updateState: currentState,
                    updateActions: basicActions,
                    aboutActions: ["Open Repo", "Copy Version", "Done"]
                ),
                requiredSemanticTokens: [
                    "About Ouro MD",
                    "Version 0.9.24 - Build surface-probe",
                    "Version 0.9.24 is current.",
                    "Last checked just now.",
                    "Check for Updates...",
                    "Open Repo",
                    "Copy Version",
                    "Done"
                ]
            ),
            AppShellAboutView(
                model: aboutModel,
                updateState: currentState,
                updateActions: basicActions,
                aboutActions: AppShellAboutActions(openRepository: {}, copyVersion: {}, dismiss: {})
            )
        )

        try measure(
            spec: SurfaceSpec(
                name: "about-available",
                width: 560,
                height: 560,
                expectedWidth: 500...540,
                expectedHeight: 470...530,
                minimumInkRatio: 0.070,
                semanticText: aboutSemantics(
                    model: aboutModel,
                    updateState: availableState,
                    updateActions: fullActions,
                    aboutActions: ["Open Repo", "Copy Version", "Done"]
                ),
                requiredSemanticTokens: [
                    "What's New in 0.9.24",
                    "Version 0.9.25 is available.",
                    "The archive and manifest are present.",
                    "Review Update",
                    "Install & Relaunch",
                    "View Release Notes"
                ]
            ),
            AppShellAboutView(
                model: aboutModel,
                updateState: availableState,
                updateActions: fullActions,
                aboutActions: AppShellAboutActions(openRepository: {}, copyVersion: {}, dismiss: {})
            )
        )

        for state in updateControlStates(availableState: availableState) {
            try measure(
                spec: updateControlSpec(for: state, actions: fullActions),
                ReleaseUpdateControls(state: state, actions: fullActions, showTitle: true)
                    .padding(12)
            )
        }

        try measure(
            spec: SurfaceSpec(
                name: "installed-confirmation",
                width: 460,
                height: 180,
                expectedWidth: 340...390,
                expectedHeight: 95...135,
                minimumInkRatio: 0.050,
                semanticText: [
                    "Ouro MD 0.9.24 is installed",
                    "The latest version is now running on this Mac.",
                    "Open About",
                    "Done"
                ].joined(separator: "\n"),
                requiredSemanticTokens: [
                    "Ouro MD 0.9.24 is installed",
                    "Open About",
                    "Done"
                ]
            ),
            UpdateInstalledConfirmationView(
                appName: "Ouro MD",
                version: "0.9.24",
                onOpenAbout: {},
                onDismiss: {}
            )
        )
    }

    private var aboutModel: AppShellAboutModel {
        AppShellAboutModel(
            identity: AppShellIdentity(
                appName: "Ouro MD",
                bundleIdentifier: "org.ourostack.ouro-md",
                repository: "ourostack/ouro-md",
                version: "0.9.24"
            ),
            versionDetail: "Build surface-probe",
            subtitle: "Independent Markdown editor for dogfooding shared native shell surfaces.",
            iconSystemName: "doc.richtext",
            whatsNew: AppShellWhatsNewModel(
                title: "What's New in 0.9.24",
                releasedText: "Released 2026-06-23",
                highlights: [
                    "Shared update controls render from the shell package.",
                    "The about view carries release context without app-local layout code."
                ],
                releaseNotesPreview: "This probe intentionally renders realistic copy, metadata, and actions."
            )
        )
    }

    private func updateControlStates(availableState: ReleaseUpdateViewState) -> [ReleaseUpdateViewState] {
        [
            .notChecked(channel: "Direct download"),
            .checking,
            .current,
            availableState,
            .installing,
            .readyToRelaunch,
            .installed,
            .unavailable,
            .failed
        ]
    }

    private func updateAvailableState() throws -> ReleaseUpdateViewState {
        let data = Data("""
        [
          {
            "tag_name": "v0.9.25",
            "html_url": "https://github.com/ourostack/ouro-md/releases/tag/v0.9.25",
            "published_at": "2026-06-23T00:00:00Z",
            "body": "## Highlights\\n- Shared shell probe\\n- Downstream apps stay honest",
            "draft": false,
            "prerelease": false,
            "assets": [
              {"name": "Ouro-MD-0.9.25.zip", "browser_download_url": "https://example.test/Ouro-MD-0.9.25.zip", "size": 7400000},
              {"name": "Ouro-MD-0.9.25.manifest.json", "browser_download_url": "https://example.test/Ouro-MD-0.9.25.manifest.json", "size": 350}
            ]
          }
        ]
        """.utf8)
        let snapshot = try ReleaseUpdateChecker.snapshot(from: data, currentVersion: "0.9.24")
        let plan = AppUpdatePlanner.plan(from: snapshot)

        return ReleaseUpdateViewState.from(snapshot: snapshot, installPlan: plan)
    }

    private func aboutSemantics(
        model: AppShellAboutModel,
        updateState: ReleaseUpdateViewState,
        updateActions: ReleaseUpdateActions,
        aboutActions: [String]
    ) -> String {
        var parts = [
            model.accessibilityLabel,
            model.appName,
            model.versionLine,
            model.subtitle,
            model.repositoryURL?.absoluteString ?? "",
            releaseUpdateSemantics(state: updateState, actions: updateActions)
        ]

        if let whatsNew = model.whatsNew {
            parts.append(whatsNew.title)
            parts.append(whatsNew.releasedText ?? "")
            parts.append(contentsOf: whatsNew.highlights)
            parts.append(whatsNew.releaseNotesPreview ?? "")
        }

        parts.append(contentsOf: aboutActions)
        return parts.joined(separator: "\n")
    }

    private func releaseUpdateSemantics(
        state: ReleaseUpdateViewState,
        actions: ReleaseUpdateActions,
        labels: ReleaseUpdateActionLabels = ReleaseUpdateActionLabels()
    ) -> String {
        var parts = [
            "Software Updates",
            "Update state",
            state.kind.label,
            state.statusLine,
            state.displayDetail ?? "",
            labels.check
        ]

        parts.append(contentsOf: state.metadata.flatMap { [$0.label, $0.value] })

        if state.canReviewUpdate, actions.reviewUpdate != nil {
            parts.append(labels.review)
        }
        if state.canInstallUpdate, actions.installAndRelaunch != nil {
            parts.append(labels.install)
        }
        if state.canOpenReleasePage, actions.openReleasePage != nil {
            parts.append(labels.openRelease)
        }

        return parts.joined(separator: "\n")
    }

    private func updateControlSpec(for state: ReleaseUpdateViewState, actions: ReleaseUpdateActions) -> SurfaceSpec {
        // Ink ratios are calibrated against both hosted CI and local Retina rendering.
        let size: (width: ClosedRange<CGFloat>, height: ClosedRange<CGFloat>, inkRatio: Double)
        switch state.kind {
        case .notChecked:
            size = (230...340, 95...145, 0.050)
        case .checking:
            size = (220...330, 95...145, 0.045)
        case .current:
            size = (220...330, 115...165, 0.045)
        case .updateAvailable:
            size = (540...660, 115...165, 0.095)
        case .installing:
            size = (220...330, 95...145, 0.040)
        case .readyToRelaunch:
            size = (260...380, 95...145, 0.060)
        case .installed:
            size = (220...330, 95...145, 0.040)
        case .unavailable:
            size = (270...390, 115...165, 0.065)
        case .failed:
            size = (390...520, 115...165, 0.060)
        }

        var required = [
            "Software Updates",
            state.kind.label,
            state.statusLine,
            ReleaseUpdateActionLabels().check
        ]
        required.append(contentsOf: state.metadata.map(\.value))
        if let detail = state.displayDetail {
            required.append(detail)
        }
        if state.canReviewUpdate {
            required.append(ReleaseUpdateActionLabels().review)
        }
        if state.canInstallUpdate {
            required.append(ReleaseUpdateActionLabels().install)
        }
        if state.canOpenReleasePage {
            required.append(ReleaseUpdateActionLabels().openRelease)
        }

        return SurfaceSpec(
            name: "updates-\(state.kind.rawValue)",
            width: 540,
            height: 170,
            expectedWidth: size.width,
            expectedHeight: size.height,
            minimumInkRatio: size.inkRatio,
            semanticText: releaseUpdateSemantics(state: state, actions: actions),
            requiredSemanticTokens: required
        )
    }

    private func measure<V: View>(spec: SurfaceSpec, _ view: V) throws {
        for token in spec.requiredSemanticTokens where !spec.semanticText.contains(token) {
            throw ProbeFailure.missingSemanticToken(name: spec.name, token: token)
        }

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: spec.width, height: spec.height)
        hostingView.layoutSubtreeIfNeeded()

        let fittingSize = hostingView.fittingSize
        guard spec.expectedWidth.contains(fittingSize.width) else {
            throw ProbeFailure.badSize(name: spec.name, axis: "width", value: fittingSize.width, expected: spec.expectedWidth)
        }
        guard spec.expectedHeight.contains(fittingSize.height) else {
            throw ProbeFailure.badSize(name: spec.name, axis: "height", value: fittingSize.height, expected: spec.expectedHeight)
        }

        let renderedInk = try renderedInk(hostingView, name: spec.name)
        guard renderedInk.ratio >= spec.minimumInkRatio else {
            throw ProbeFailure.insufficientRender(
                name: spec.name,
                nonBlankPixels: renderedInk.nonBlankPixels,
                totalPixels: renderedInk.totalPixels,
                ratio: renderedInk.ratio,
                minimumRatio: spec.minimumInkRatio
            )
        }

        print(
            "\(spec.name): \(Int(fittingSize.width))x\(Int(fittingSize.height)), "
                + "pixels=\(renderedInk.nonBlankPixels)/\(renderedInk.totalPixels), "
                + "ink=\(String(format: "%.3f", renderedInk.ratio)), "
                + "min=\(String(format: "%.3f", spec.minimumInkRatio))"
        )
    }

    private func renderedInk(_ view: NSView, name: String) throws -> RenderedInk {
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw ProbeFailure.missingBitmap(name: name)
        }
        view.cacheDisplay(in: view.bounds, to: representation)

        let width = representation.pixelsWide
        let height = representation.pixelsHigh
        var count = 0

        for y in 0..<height {
            for x in 0..<width {
                guard let color = representation.colorAt(x: x, y: y) else {
                    continue
                }
                let calibrated = color.usingColorSpace(.deviceRGB) ?? color
                if calibrated.alphaComponent > 0.01
                    && (calibrated.redComponent < 0.96
                        || calibrated.greenComponent < 0.96
                        || calibrated.blueComponent < 0.96)
                {
                    count += 1
                }
            }
        }

        return RenderedInk(nonBlankPixels: count, totalPixels: width * height)
    }
}

private struct RenderedInk {
    var nonBlankPixels: Int
    var totalPixels: Int

    var ratio: Double {
        guard totalPixels > 0 else {
            return 0
        }
        return Double(nonBlankPixels) / Double(totalPixels)
    }
}

private struct SurfaceSpec {
    var name: String
    var width: CGFloat
    var height: CGFloat
    var expectedWidth: ClosedRange<CGFloat>
    var expectedHeight: ClosedRange<CGFloat>
    var minimumInkRatio: Double
    var semanticText: String
    var requiredSemanticTokens: [String]
}

private extension ReleaseUpdateViewState {
    static let checking = ReleaseUpdateViewState(
        kind: .checking,
        statusLine: "Checking GitHub releases...",
        metadata: [ReleaseUpdateMetadataItem(label: "Channel", value: "Direct download")]
    )

    static let current = ReleaseUpdateViewState(
        kind: .current,
        statusLine: "Version 0.9.24 is current.",
        metadata: [
            ReleaseUpdateMetadataItem(label: "Current", value: "0.9.24"),
            ReleaseUpdateMetadataItem(label: "Latest", value: "0.9.24")
        ],
        detail: "Last checked just now."
    )

    static let installing = ReleaseUpdateViewState(
        kind: .installing,
        statusLine: "Installing 0.9.25...",
        metadata: [ReleaseUpdateMetadataItem(label: "Latest", value: "0.9.25")]
    )

    static let readyToRelaunch = ReleaseUpdateViewState(
        kind: .readyToRelaunch,
        statusLine: "0.9.25 is ready to relaunch.",
        metadata: [ReleaseUpdateMetadataItem(label: "Latest", value: "0.9.25")],
        canInstallUpdate: true
    )

    static let installed = ReleaseUpdateViewState(
        kind: .installed,
        statusLine: "0.9.25 is installed.",
        metadata: [ReleaseUpdateMetadataItem(label: "Latest", value: "0.9.25")]
    )

    static let unavailable = ReleaseUpdateViewState(
        kind: .unavailable,
        statusLine: "Release metadata is unavailable.",
        metadata: [ReleaseUpdateMetadataItem(label: "Channel", value: "Direct download")],
        detail: "Try again when the network is available.",
        canOpenReleasePage: true
    )

    static let failed = ReleaseUpdateViewState(
        kind: .failed,
        statusLine: "Install failed.",
        metadata: [ReleaseUpdateMetadataItem(label: "Latest", value: "0.9.25")],
        warning: "Downloaded archive failed verification.",
        canReviewUpdate: true,
        canOpenReleasePage: true
    )
}

private enum ProbeFailure: Error, CustomStringConvertible {
    case badSize(name: String, axis: String, value: CGFloat, expected: ClosedRange<CGFloat>)
    case insufficientRender(name: String, nonBlankPixels: Int, totalPixels: Int, ratio: Double, minimumRatio: Double)
    case missingBitmap(name: String)
    case missingSemanticToken(name: String, token: String)

    var description: String {
        switch self {
        case let .badSize(name, axis, value, expected):
            return "\(name) \(axis) \(value) outside \(expected.lowerBound)...\(expected.upperBound)"
        case let .insufficientRender(name, nonBlankPixels, totalPixels, ratio, minimumRatio):
            return "\(name) rendered only \(nonBlankPixels)/\(totalPixels) non-blank pixels (\(ratio)); expected at least \(minimumRatio)"
        case let .missingBitmap(name):
            return "\(name) did not produce a cacheable bitmap"
        case let .missingSemanticToken(name, token):
            return "\(name) missing semantic token: \(token)"
        }
    }
}
