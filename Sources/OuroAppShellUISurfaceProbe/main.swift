import AppKit
import Foundation
import SwiftUI
import Vision
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
                minimumInkRatio: 0.035,
                requiredRenderedText: [
                    "Ouro MD",
                    "Version 0.9.24",
                    "Build surface-probe",
                    "0.9.24 is current",
                    "Last checked",
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
                minimumInkRatio: 0.045,
                requiredRenderedText: [
                    "Ouro MD",
                    "Version 0.9.24",
                    "What's New",
                    "0.9.25 is available",
                    "archive and manifest",
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
                requiredRenderedText: [
                    "Ouro MD 0.9.24 is installed",
                    "latest version is now running",
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

    private func updateControlSpec(for state: ReleaseUpdateViewState, actions: ReleaseUpdateActions) -> SurfaceSpec {
        // OCR is the primary text gate; ink remains a conservative nonblank guard
        // across hosted non-Retina CI and local Retina rendering.
        let size: (width: ClosedRange<CGFloat>, height: ClosedRange<CGFloat>, inkRatio: Double)
        switch state.kind {
        case .notChecked:
            size = (230...340, 95...145, 0.025)
        case .checking:
            size = (220...330, 95...145, 0.010)
        case .current:
            size = (220...330, 115...165, 0.025)
        case .updateAvailable:
            size = (540...660, 115...165, 0.075)
        case .installing:
            size = (220...330, 95...145, 0.020)
        case .readyToRelaunch:
            size = (260...380, 95...145, 0.035)
        case .installed:
            size = (220...330, 95...145, 0.020)
        case .unavailable:
            size = (270...390, 115...165, 0.045)
        case .failed:
            size = (390...520, 115...165, 0.055)
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
            requiredRenderedText: required
        )
    }

    private func measure<V: View>(spec: SurfaceSpec, _ view: V) throws {
        let fittingView = NSHostingView(
            rootView: view
                .environment(\.colorScheme, .light)
        )
        fittingView.frame = NSRect(x: 0, y: 0, width: spec.width, height: spec.height)
        fittingView.layoutSubtreeIfNeeded()

        let fittingSize = fittingView.fittingSize
        guard spec.expectedWidth.contains(fittingSize.width) else {
            throw ProbeFailure.badSize(name: spec.name, axis: "width", value: fittingSize.width, expected: spec.expectedWidth)
        }
        guard spec.expectedHeight.contains(fittingSize.height) else {
            throw ProbeFailure.badSize(name: spec.name, axis: "height", value: fittingSize.height, expected: spec.expectedHeight)
        }

        let renderingView = NSHostingView(
            rootView: ZStack(alignment: .topLeading) {
                Color.white
                view
                    .environment(\.colorScheme, .light)
            }
            .frame(width: spec.width, height: spec.height, alignment: .topLeading)
        )
        renderingView.frame = NSRect(x: 0, y: 0, width: spec.width, height: spec.height)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: spec.width, height: spec.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = renderingView
        window.setFrameOrigin(NSPoint(x: -30000, y: -30000))
        window.makeKeyAndOrderFront(nil)
        defer {
            window.orderOut(nil)
        }
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.08))
        renderingView.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        renderingView.displayIfNeeded()

        let renderedSurface = try renderedSurface(renderingView, name: spec.name)
        guard renderedSurface.ink.ratio >= spec.minimumInkRatio else {
            throw ProbeFailure.insufficientRender(
                name: spec.name,
                nonBlankPixels: renderedSurface.ink.nonBlankPixels,
                totalPixels: renderedSurface.ink.totalPixels,
                ratio: renderedSurface.ink.ratio,
                minimumRatio: spec.minimumInkRatio
            )
        }

        let renderedText = recognizeText(in: renderedSurface.image)
        for token in spec.requiredRenderedText where !renderedTextContains(renderedText, token) {
            throw ProbeFailure.missingRenderedText(name: spec.name, token: token, recognizedText: renderedText)
        }

        print(
            "\(spec.name): \(Int(fittingSize.width))x\(Int(fittingSize.height)), "
                + "pixels=\(renderedSurface.ink.nonBlankPixels)/\(renderedSurface.ink.totalPixels), "
                + "ink=\(String(format: "%.3f", renderedSurface.ink.ratio)), "
                + "min=\(String(format: "%.3f", spec.minimumInkRatio)), "
                + "ocr=\(renderedText.count)"
        )
    }

    private func renderedSurface(_ view: NSView, name: String) throws -> RenderedSurface {
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw ProbeFailure.missingBitmap(name: name)
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let image = representation.cgImage else {
            throw ProbeFailure.missingBitmap(name: name)
        }
        saveDebugSnapshot(image, name: name)

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

        return RenderedSurface(image: image, ink: RenderedInk(nonBlankPixels: count, totalPixels: width * height))
    }

    private func saveDebugSnapshot(_ image: CGImage, name: String) {
        guard ProcessInfo.processInfo.environment["OURO_APP_SHELL_UI_SURFACE_DEBUG_SNAPSHOT"] != nil else {
            return
        }
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ouro-app-shell-\(name).png")
        try? data.write(to: url)
        print("debug snapshot: \(url.path)")
    }

    private func recognizeText(in image: CGImage) -> Set<String> {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return Set((request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first?.string
        })
    }

    private func renderedTextContains(_ renderedText: Set<String>, _ token: String) -> Bool {
        renderedText.contains { line in
            line.localizedCaseInsensitiveContains(token)
        }
    }
}

private struct RenderedSurface {
    var image: CGImage
    var ink: RenderedInk
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
    var requiredRenderedText: [String]
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
    case missingRenderedText(name: String, token: String, recognizedText: Set<String>)

    var description: String {
        switch self {
        case let .badSize(name, axis, value, expected):
            return "\(name) \(axis) \(value) outside \(expected.lowerBound)...\(expected.upperBound)"
        case let .insufficientRender(name, nonBlankPixels, totalPixels, ratio, minimumRatio):
            return "\(name) rendered only \(nonBlankPixels)/\(totalPixels) non-blank pixels (\(ratio)); expected at least \(minimumRatio)"
        case let .missingBitmap(name):
            return "\(name) did not produce a cacheable bitmap"
        case let .missingRenderedText(name, token, recognizedText):
            let observed = recognizedText.sorted().joined(separator: " | ")
            return "\(name) missing rendered text token: \(token); recognized: \(observed)"
        }
    }
}
