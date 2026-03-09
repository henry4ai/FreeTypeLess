import Foundation

/// Locates resource files in both the .app bundle (installed) and the
/// project source tree (when launched via `swift run`).
enum ResourceLocator {
    /// Returns the URL for a resource file, searching:
    /// 1. Bundle.main (works for signed .app bundles)
    /// 2. Project Resources/ directory relative to the executable (works for `swift run`)
    static func url(forResource name: String, withExtension ext: String, subdirectory: String? = nil) -> URL? {
        // 1. Try Bundle.main (signed .app) — with and without subdirectory
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            print("[ResourceLocator] Found via Bundle.main: \(url.path)")
            return url
        }
        // Also try without subdirectory (flat Resources/ in .app bundle)
        if subdirectory != nil, let url = Bundle.main.url(forResource: name, withExtension: ext) {
            print("[ResourceLocator] Found via Bundle.main (no subdir): \(url.path)")
            return url
        }

        // 2. Try project root Resources/ directory
        //    swift run executable lives at .build/<arch>/debug/SwiftTypeless
        //    Project root is 4 levels up from the executable.
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let projectRoot = execURL
            .deletingLastPathComponent()  // debug/
            .deletingLastPathComponent()  // <arch>/
            .deletingLastPathComponent()  // .build/
            .deletingLastPathComponent()  // project root

        let resourcesDir = projectRoot.appendingPathComponent("Resources")

        let fileURL: URL
        if let sub = subdirectory {
            fileURL = resourcesDir.appendingPathComponent(sub).appendingPathComponent("\(name).\(ext)")
        } else {
            fileURL = resourcesDir.appendingPathComponent("\(name).\(ext)")
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        // 3. Also try subdirectory as a path within Resources/
        if let sub = subdirectory {
            let altURL = resourcesDir.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: altURL.path) {
                return altURL
            }
            // Try as nested path: Resources/audio/beg.WAV etc.
            let nestedURL = resourcesDir.appendingPathComponent(sub).appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: nestedURL.path) {
                return nestedURL
            }
        }

        return nil
    }
}
