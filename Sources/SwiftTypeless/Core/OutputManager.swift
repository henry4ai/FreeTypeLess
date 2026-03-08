import AppKit

enum OutputManager {
    /// Copy text to clipboard and simulate Cmd+V paste
    static func output(_ text: String) async {
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Wait for clipboard readiness
        try? await Task.sleep(for: .milliseconds(100))

        // Simulate Cmd+V via AppleScript
        let script = NSAppleScript(source: """
            tell application "System Events" to keystroke "v" using command down
        """)
        var errorInfo: NSDictionary?
        script?.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            print("[OutputManager] AppleScript error: \(error)")
        }
    }

    /// Copy text to clipboard without pasting
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
