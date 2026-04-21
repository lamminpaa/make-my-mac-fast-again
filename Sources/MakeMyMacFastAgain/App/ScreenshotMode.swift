import AppKit
import SwiftUI

@MainActor
final class ScreenshotController {
    static let shared = ScreenshotController()

    private let features: [(NavigationItem, String)] = [
        (.dashboard, "01-dashboard"),
        (.cacheCleaner, "02-cache-cleaner"),
        (.browserCleanup, "03-browser-cleanup"),
        (.largeFileFinder, "04-large-file-finder"),
        (.processManager, "05-process-manager"),
        (.zombiePollers, "06-zombie-pollers"),
        (.startupItems, "07-startup-items"),
        (.memoryOptimizer, "08-memory-optimizer"),
        (.dnsFlush, "09-dns-flush")
    ]

    var onSelectItem: ((NavigationItem) -> Void)?
    private var outputDir: String = ""

    func runScreenshotMode(outputDir: String) {
        self.outputDir = outputDir

        // Create output dir if needed
        try? FileManager.default.createDirectory(
            atPath: outputDir,
            withIntermediateDirectories: true
        )

        // Start cycling through features after a brief delay for the UI to load
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            await captureAllFeatures()
            NSApp.terminate(nil)
        }
    }

    private func captureAllFeatures() async {
        for (item, filename) in features {
            onSelectItem?(item)

            // Wait for the view to render
            try? await Task.sleep(for: .seconds(1.5))

            captureMainWindow(filename: filename)
        }
    }

    private func captureMainWindow(filename: String) {
        guard let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            print("No window found for \(filename)")
            return
        }

        guard let view = window.contentView else {
            print("No content view for \(filename)")
            return
        }

        let bounds = view.bounds
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            print("Could not create bitmap for \(filename)")
            return
        }

        view.cacheDisplay(in: bounds, to: bitmap)

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("Could not create PNG for \(filename)")
            return
        }

        let path = "\(outputDir)/\(filename).png"
        do {
            try pngData.write(to: URL(fileURLWithPath: path))
            print("Saved: \(path)")
        } catch {
            print("Error saving \(filename): \(error)")
        }
    }
}
