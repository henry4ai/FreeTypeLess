import AppKit
import ApplicationServices

enum SelectedTextDetector {
    /// Get the currently selected text in the frontmost application via Accessibility API.
    /// Returns empty string if no selection or if accessibility permission is denied.
    static func detect() -> String {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return "" }

        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        // Get focused UI element
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        guard focusedResult == .success, let focusedElement = focusedValue else { return "" }

        // Get selected text attribute
        var selectedValue: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedValue)
        guard selectedResult == .success, let text = selectedValue as? String else { return "" }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
