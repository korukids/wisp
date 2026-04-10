import Foundation

// Override SPM's auto-generated Bundle.module to look in Contents/Resources/
// for proper app bundle structure (required for code signing).
extension Foundation.Bundle {
    static let moduleResources: Bundle = {
        // For app bundles: look in Contents/Resources/
        if let resourceURL = Bundle.main.resourceURL {
            let bundlePath = resourceURL.appendingPathComponent("Wisp_Wisp.bundle").path
            if let bundle = Bundle(path: bundlePath) {
                return bundle
            }
        }

        // Fallback to Bundle.main (for running directly during development)
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("Wisp_Wisp.bundle").path
        if let bundle = Bundle(path: mainPath) {
            return bundle
        }

        // Final fallback: adjacent to executable (SPM build directory)
        let executableURL = Bundle.main.executableURL?.deletingLastPathComponent()
        if let execPath = executableURL?.appendingPathComponent("Wisp_Wisp.bundle").path,
           let bundle = Bundle(path: execPath) {
            return bundle
        }

        fatalError("Could not load Wisp_Wisp.bundle resource bundle")
    }()
}
