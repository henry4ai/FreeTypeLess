import SwiftUI
import AppKit

/// Transparent NSView subclass to prevent default background drawing
private final class ClearHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Ensure the underlying layer is fully transparent
        window?.isOpaque = false
        layer?.backgroundColor = .clear
        layer?.isOpaque = false
    }
}

final class OverlayWindowController {
    private var window: NSWindow?
    private let appState = AppState.shared

    func show() {
        if window == nil {
            createWindow()
        }
        positionAtBottomCenter()
        // showInactive equivalent — show without stealing focus
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func updateSize(width: CGFloat, height: CGFloat) {
        guard let window else { return }
        let currentFrame = window.frame
        if abs(currentFrame.width - width) < 1 && abs(currentFrame.height - height) < 1 { return }

        window.setContentSize(NSSize(width: width, height: height))
        // Always re-center on screen after resizing
        positionAtBottomCenter()
    }

    private func createWindow() {
        let contentView = OverlayPanel()
            .environment(appState)

        let hostingView = ClearHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        hostingView.layer?.isOpaque = false

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 36),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.contentView = hostingView
        win.isOpaque = false
        win.backgroundColor = .clear
        // Match original: level 'screen-saver' — above everything including fullscreen
        win.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.hasShadow = false
        win.ignoresMouseEvents = true
        window = win
    }

    private func positionAtBottomCenter() {
        // Position on screen nearest to cursor (matches original logic)
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen, let window else { return }

        let workArea = screen.visibleFrame
        let x = workArea.origin.x + (workArea.width - window.frame.width) / 2
        let y = workArea.origin.y + 80
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
