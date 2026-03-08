import AppKit
import SwiftUI

/// Borderless window that can become key (receive keyboard events)
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayController: OverlayWindowController?
    private var qaWindow: NSWindow?
    private let appState = AppState.shared
    private var observationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app behaves as a regular foreground app even when
        // launched via `swift run` (which bypasses Info.plist).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        setupTrayMenu()
        overlayController = OverlayWindowController()
        startObserving()
        setupEscMonitor()
        appState.startListening()
        checkAccessibilityPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stopListening()
        observationTask?.cancel()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    // MARK: - Tray Menu

    private func setupTrayMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let iconURL = Bundle.main.url(forResource: "hands", withExtension: "png", subdirectory: "Resources"),
               let icon = NSImage(contentsOf: iconURL) {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            } else {
                // Fallback to SF Symbol
                button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "SwiftTypeless")
                button.image?.size = NSSize(width: 18, height: 18)
                button.image?.isTemplate = true
            }
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Show", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Settings", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")

        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title != "" && !($0.level == .floating) }?.makeKeyAndOrderFront(nil)
    }

    @objc private func showSettings() {
        showMainWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - State Observation

    private func startObserving() {
        observationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var lastOverlay = false
            var lastQA = false
            var lastStatus: AppStatus = .ready

            while !Task.isCancelled {
                // Use a short sleep for polling — withObservationTracking doesn't work
                // well across actor boundaries in this context
                try? await Task.sleep(for: .milliseconds(50))

                let shouldShowOverlay = appState.showOverlay
                if shouldShowOverlay != lastOverlay {
                    lastOverlay = shouldShowOverlay
                    if shouldShowOverlay {
                        print("[AppDelegate] Showing overlay")
                        overlayController?.show()
                    } else {
                        print("[AppDelegate] Hiding overlay")
                        overlayController?.hide()
                    }
                }

                // Resize overlay only when status changes (not every poll)
                let currentStatus = appState.status
                if currentStatus != lastStatus {
                    lastStatus = currentStatus
                    if case .error = currentStatus {
                        overlayController?.updateSize(width: 180, height: 44)
                    } else if case .recording(let mode) = currentStatus, mode != .transcribe {
                        overlayController?.updateSize(width: 260, height: 78)
                    } else if shouldShowOverlay {
                        overlayController?.updateSize(width: 100, height: 36)
                    }
                }

                let shouldShowQA = appState.showQAWindow
                if shouldShowQA != lastQA {
                    lastQA = shouldShowQA
                    if shouldShowQA {
                        showQAResultWindow()
                    } else {
                        qaWindow?.close()
                        qaWindow = nil
                    }
                }
            }
        }
    }

    // MARK: - QA Window

    private func showQAResultWindow() {
        if qaWindow == nil {
            let contentView = QAResultView()
                .environment(appState)

            let window = KeyableWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
                styleMask: [.borderless, .resizable],
                backing: .buffered,
                defer: false
            )
            window.contentView = NSHostingView(rootView: contentView)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.center()
            window.collectionBehavior = [.canJoinAllSpaces]
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = true
            window.hasShadow = true
            window.minSize = NSSize(width: 400, height: 200)
            qaWindow = window
        }

        qaWindow?.level = .floating
        qaWindow?.orderFrontRegardless()
        qaWindow?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupEscMonitor() {
        // Local monitor: catches ESC when QA window is key within our app
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53, self.qaWindow?.isVisible == true {
                self.appState.showQAWindow = false
                return nil
            }
            return event
        }

        // Global monitor: catches ESC even when another app has focus
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if event.keyCode == 53, self.qaWindow?.isVisible == true {
                DispatchQueue.main.async {
                    self.appState.showQAWindow = false
                }
            }
        }
    }

    // MARK: - Permissions

    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            print("[App] Accessibility permission requested")
        }
    }
}
