import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Check for --screenshots flag
if let screenshotIndex = CommandLine.arguments.firstIndex(of: "--screenshots") {
    let outputDir: String
    if screenshotIndex + 1 < CommandLine.arguments.count {
        outputDir = CommandLine.arguments[screenshotIndex + 1]
    } else {
        outputDir = "screenshots"
    }
    ScreenshotController.shared.runScreenshotMode(outputDir: outputDir)
}

app.run()
