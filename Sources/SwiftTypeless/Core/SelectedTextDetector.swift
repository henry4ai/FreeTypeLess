import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum SelectedTextDetector {
    /// Get the currently selected text in the frontmost application.
    /// Tries Accessibility API first, falls back to simulating Cmd+C for apps (e.g. browsers)
    /// that don't expose selected text via accessibility attributes.
    static func detect() -> String {
        // Try Accessibility API first (fast, no side effects)
        let axText = detectViaAccessibility()
        if !axText.isEmpty {
            print("[SelectedText] Got text via Accessibility API (\(axText.count) chars)")
            return axText
        }
        print("[SelectedText] Accessibility API returned empty, trying clipboard fallback")

        // Fallback: simulate Cmd+C and read from clipboard
        let clipText = detectViaClipboard()
        if !clipText.isEmpty {
            print("[SelectedText] Got text via clipboard fallback (\(clipText.count) chars)")
        } else {
            print("[SelectedText] Clipboard fallback also returned empty")
        }
        return clipText
    }

    // MARK: - Accessibility API

    private static func detectViaAccessibility() -> String {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            print("[SelectedText] No frontmost application")
            return ""
        }
        print("[SelectedText] Frontmost app: \(focusedApp.localizedName ?? "unknown")")

        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        guard focusedResult == .success, let focusedElement = focusedValue else {
            print("[SelectedText] AX: Failed to get focused element (code: \(focusedResult.rawValue))")
            return ""
        }

        var selectedValue: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedValue)
        guard selectedResult == .success, let text = selectedValue as? String else {
            print("[SelectedText] AX: Failed to get selected text (code: \(selectedResult.rawValue))")
            return ""
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Clipboard fallback (for browsers etc.)

    private static func detectViaClipboard() -> String {
        let pasteboard = NSPasteboard.general
        let oldChangeCount = pasteboard.changeCount

        // Save current clipboard content
        let savedItems: [(NSPasteboard.PasteboardType, Data)] = pasteboard.pasteboardItems?.flatMap { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        } ?? []

        // Simulate Cmd+C using a private event source (avoids inheriting
        // physical modifier state — Option key may be held down)
        simulateCopy()

        // Run the main run loop briefly so our event tap can forward
        // the synthetic Cmd+C to the target app, then give it time to update the pasteboard.
        CFRunLoopRunInMode(.defaultMode, 0.15, false)

        // Check if clipboard changed
        guard pasteboard.changeCount != oldChangeCount else {
            print("[SelectedText] Clipboard: changeCount unchanged, no copy happened")
            return ""
        }

        let text = (pasteboard.string(forType: .string) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // Restore original clipboard
        pasteboard.clearContents()
        for (type, data) in savedItems {
            pasteboard.setData(data, forType: type)
        }

        return text
    }

    private static func simulateCopy() {
        // Use private state so the event doesn't inherit physical key state
        // (Option key is held down when this is called)
        let src = CGEventSource(stateID: .privateState)

        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: UInt16(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: UInt16(kVK_ANSI_C), keyDown: false)
        else {
            print("[SelectedText] Failed to create CGEvents for Cmd+C")
            return
        }

        // Set ONLY Command flag — no Option, no Shift
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
