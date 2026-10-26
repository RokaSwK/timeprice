import AppKit
import SwiftUI

/// Borderless, non-activating, always-on-top panel pinned to the top centre of
/// the built-in display. It can become key (for the salary field) without
/// activating the app, so the frontmost app keeps focus.
final class NotchPanel: NSPanel {
    init(size: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        (windowController as? NotchWindowController)?.model.close()
    }
}

@MainActor
final class NotchWindowController: NSWindowController {
    let model: NotchModel
    private var tick: Timer?
    private var poll: Timer?
    private var leftAt: Date?
    private var clickMonitor: Any?
    private var screenObserver: Any?

    init(model: NotchModel) {
        self.model = model
        let panel = NotchPanel(size: model.metrics.canvas)
        super.init(window: panel)
        let host = NSHostingView(rootView: NotchRootView(model: model))
        host.sizingOptions = []
        panel.contentView = host
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// The built-in display if there is one (that's where the notch is), else the main screen.
    static var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    func start() {
        place()
        window?.orderFrontRegardless()
        tick = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.now = Date() }
        }
        // Polling the pointer is cheap and needs no Accessibility permission.
        poll = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackPointer() }
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.model.presentation == .panel, !self.pointerInside(margin: 0) else { return }
                self.model.close()
            }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.place() }
        }
    }

    func place() {
        guard let window, let screen = Self.targetScreen else { return }
        model.metrics = NotchMetrics.from(screen)
        let canvas = model.metrics.canvas
        let origin = NSPoint(x: screen.frame.midX - canvas.width / 2, y: screen.frame.maxY - canvas.height)
        window.setFrame(NSRect(origin: origin, size: canvas), display: true)
    }

    /// Screen rectangle currently covered by the black shape.
    private func shapeRect(margin: CGFloat) -> NSRect {
        guard let window else { return .zero }
        let size = model.size
        let frame = window.frame
        return NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
            .insetBy(dx: -margin, dy: -margin)
    }

    private func pointerInside(margin: CGFloat) -> Bool {
        shapeRect(margin: margin).contains(NSEvent.mouseLocation)
    }

    private func trackPointer() {
        guard let window else { return }
        // Generous margin at rest so the slim pill is easy to hit.
        let inside = pointerInside(margin: model.presentation.isRest ? 4 : 2)
        window.ignoresMouseEvents = !inside
        if model.pinned { return }
        switch model.presentation {
        case .rest, .expanded:
            model.hover(inside)
        case .alert:
            if inside { leftAt = nil }
        case .panel:
            if inside {
                leftAt = nil
                if !window.isKeyWindow { window.makeKey() }
            } else if let leftAt {
                if Date().timeIntervalSince(leftAt) > 1.2 { model.close(); self.leftAt = nil }
            } else {
                leftAt = Date()
            }
        }
        if model.presentation != .panel, window.isKeyWindow { window.resignKey() }
    }
}
