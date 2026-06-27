#if os(macOS)
import AppKit
import SwiftUI
import OuroAppShellUI

@MainActor
public struct AppShellWindowSpec: Equatable {
    public var title: String
    public var width: CGFloat
    public var height: CGFloat
    public var minWidth: CGFloat?
    public var minHeight: CGFloat?
    public var styleMask: NSWindow.StyleMask
    public var shouldCenter: Bool
    public var shouldActivateApp: Bool

    public init(
        title: String,
        width: CGFloat,
        height: CGFloat,
        minWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        styleMask: NSWindow.StyleMask = [.titled, .closable],
        shouldCenter: Bool = true,
        shouldActivateApp: Bool = true
    ) {
        self.title = title
        self.width = width
        self.height = height
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.styleMask = styleMask
        self.shouldCenter = shouldCenter
        self.shouldActivateApp = shouldActivateApp
    }
}

@MainActor
public final class AppShellWindowPresenter {
    private var windows: [String: NSWindow] = [:]

    public init() {}

    @discardableResult
    public func present<Content: View>(
        id: String,
        spec: AppShellWindowSpec,
        @ViewBuilder content: () -> Content
    ) -> NSWindow {
        let window = windows[id] ?? makeWindow(spec: spec)
        windows[id] = window
        window.contentViewController = NSHostingController(rootView: content())
        apply(spec: spec, to: window)
        window.makeKeyAndOrderFront(nil)
        if spec.shouldActivateApp {
            NSApp.activate(ignoringOtherApps: true)
        }
        return window
    }

    public func close(id: String) {
        windows[id]?.orderOut(nil)
    }

    public func window(for id: String) -> NSWindow? {
        windows[id]
    }

    private func makeWindow(spec: AppShellWindowSpec) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: spec.width, height: spec.height),
            styleMask: spec.styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = spec.title
        window.isReleasedWhenClosed = false
        if spec.shouldCenter {
            window.center()
        }
        apply(spec: spec, to: window)
        return window
    }

    private func apply(spec: AppShellWindowSpec, to window: NSWindow) {
        window.title = spec.title
        window.styleMask = spec.styleMask
        if let minWidth = spec.minWidth, let minHeight = spec.minHeight {
            window.minSize = NSSize(width: minWidth, height: minHeight)
        }
    }
}
#endif
