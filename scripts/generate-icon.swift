#!/usr/bin/env swift

import AppKit
import Foundation

// MARK: - Icon Generator for "Make My Mac Fast Again"
// Generates a professional macOS app icon with a speedometer/gauge design.

/// Draws the app icon at the given size into the current NSGraphicsContext.
func drawIcon(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    // --- Background: macOS-style rounded rectangle with gradient ---
    let cornerRadius = size * 0.22 // Apple-style squircle proportion
    let backgroundPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.02, dy: size * 0.02),
                                       xRadius: cornerRadius, yRadius: cornerRadius)

    // Deep blue to teal gradient
    let deepBlue = NSColor(calibratedRed: 0.102, green: 0.227, blue: 0.361, alpha: 1.0)  // #1a3a5c
    let teal = NSColor(calibratedRed: 0.173, green: 0.647, blue: 0.647, alpha: 1.0)       // #2ca5a5

    let gradient = NSGradient(starting: deepBlue, ending: teal)!
    gradient.draw(in: backgroundPath, angle: -45) // top-left to bottom-right

    // Subtle inner shadow / edge highlight
    let innerRect = rect.insetBy(dx: size * 0.03, dy: size * 0.03)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: cornerRadius * 0.92, yRadius: cornerRadius * 0.92)
    let innerGradient = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.08),
        NSColor.clear,
        NSColor.black.withAlphaComponent(0.12)
    ], atLocations: [0.0, 0.5, 1.0], colorSpace: .deviceRGB)!
    innerGradient.draw(in: innerPath, angle: -90)

    // --- Center point for gauge ---
    let centerX = size * 0.5
    let centerY = size * 0.38
    let gaugeRadius = size * 0.30

    // --- Gauge arc background (track) ---
    // Arc from 210 degrees (7 o'clock) to 330 degrees (5 o'clock), measured counter-clockwise from 3 o'clock
    let startAngle: CGFloat = 210
    let endAngle: CGFloat = 330

    let trackPath = NSBezierPath()
    trackPath.appendArc(withCenter: NSPoint(x: centerX, y: centerY),
                        radius: gaugeRadius,
                        startAngle: startAngle,
                        endAngle: endAngle,
                        clockwise: false)
    trackPath.lineWidth = size * 0.045
    trackPath.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.2).setStroke()
    trackPath.stroke()

    // --- Gauge colored segments ---
    // Slow (red-ish) zone: 210 to 250
    // Medium (yellow) zone: 250 to 290
    // Fast (green/bright) zone: 290 to 330
    drawArcSegment(center: NSPoint(x: centerX, y: centerY), radius: gaugeRadius,
                   from: 210, to: 255, width: size * 0.045,
                   color: NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.3, alpha: 0.85))
    drawArcSegment(center: NSPoint(x: centerX, y: centerY), radius: gaugeRadius,
                   from: 255, to: 295, width: size * 0.045,
                   color: NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.25, alpha: 0.85))
    drawArcSegment(center: NSPoint(x: centerX, y: centerY), radius: gaugeRadius,
                   from: 295, to: 330, width: size * 0.045,
                   color: NSColor(calibratedRed: 0.3, green: 0.9, blue: 0.5, alpha: 0.9))

    // --- Tick marks around the gauge ---
    let tickCount = 9
    for i in 0...tickCount {
        let angle = startAngle + (endAngle - startAngle) * CGFloat(i) / CGFloat(tickCount)
        let radians = angle * .pi / 180.0
        let isMajor = (i % 3 == 0)
        let innerR = gaugeRadius - (isMajor ? size * 0.06 : size * 0.04)
        let outerR = gaugeRadius + size * 0.03

        let tickPath = NSBezierPath()
        tickPath.move(to: NSPoint(x: centerX + innerR * cos(radians),
                                   y: centerY + innerR * sin(radians)))
        tickPath.line(to: NSPoint(x: centerX + outerR * cos(radians),
                                   y: centerY + outerR * sin(radians)))
        tickPath.lineWidth = isMajor ? size * 0.018 : size * 0.01
        tickPath.lineCapStyle = .round
        NSColor.white.withAlphaComponent(isMajor ? 0.9 : 0.5).setStroke()
        tickPath.stroke()
    }

    // --- Needle pointing to "fast" zone (~315 degrees, roughly 2 o'clock) ---
    let needleAngle: CGFloat = 320 * .pi / 180.0
    let needleLength = gaugeRadius * 0.85
    let needleTip = NSPoint(x: centerX + needleLength * cos(needleAngle),
                             y: centerY + needleLength * sin(needleAngle))

    // Needle shadow
    let shadowNeedle = NSBezierPath()
    shadowNeedle.move(to: NSPoint(x: centerX + size * 0.005, y: centerY - size * 0.005))
    shadowNeedle.line(to: NSPoint(x: needleTip.x + size * 0.005, y: needleTip.y - size * 0.005))
    shadowNeedle.lineWidth = size * 0.028
    shadowNeedle.lineCapStyle = .round
    NSColor.black.withAlphaComponent(0.3).setStroke()
    shadowNeedle.stroke()

    // Needle body
    let needlePath = NSBezierPath()
    needlePath.move(to: NSPoint(x: centerX, y: centerY))
    needlePath.line(to: needleTip)
    needlePath.lineWidth = size * 0.025
    needlePath.lineCapStyle = .round
    NSColor.white.setStroke()
    needlePath.stroke()

    // Needle center cap (hub)
    let hubRadius = size * 0.04
    let hubRect = NSRect(x: centerX - hubRadius, y: centerY - hubRadius,
                          width: hubRadius * 2, height: hubRadius * 2)
    let hubPath = NSBezierPath(ovalIn: hubRect)
    NSColor.white.setFill()
    hubPath.fill()

    // Inner hub dot
    let innerHubRadius = size * 0.018
    let innerHubRect = NSRect(x: centerX - innerHubRadius, y: centerY - innerHubRadius,
                               width: innerHubRadius * 2, height: innerHubRadius * 2)
    let innerHubPath = NSBezierPath(ovalIn: innerHubRect)
    teal.setFill()
    innerHubPath.fill()

    // --- Lightning bolt near the needle tip ---
    drawLightningBolt(near: needleTip, size: size)

    // --- Speed lines (motion streaks) near the right side ---
    drawSpeedLines(centerX: centerX, centerY: centerY, gaugeRadius: gaugeRadius, size: size)

    // --- "FAST" label below the gauge ---
    drawLabel(text: "FAST", centerX: centerX, y: centerY - gaugeRadius * 0.55, size: size)
}

/// Draws a colored arc segment on the gauge.
func drawArcSegment(center: NSPoint, radius: CGFloat, from startDeg: CGFloat, to endDeg: CGFloat,
                    width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius,
                   startAngle: startDeg, endAngle: endDeg, clockwise: false)
    path.lineWidth = width
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}

/// Draws a small lightning bolt icon near the given point.
func drawLightningBolt(near point: NSPoint, size: CGFloat) {
    let s = size * 0.06 // scale factor for the bolt
    let ox = point.x + size * 0.04
    let oy = point.y + size * 0.03

    let bolt = NSBezierPath()
    bolt.move(to: NSPoint(x: ox - s * 0.2, y: oy + s * 1.2))
    bolt.line(to: NSPoint(x: ox + s * 0.15, y: oy + s * 0.2))
    bolt.line(to: NSPoint(x: ox - s * 0.05, y: oy + s * 0.2))
    bolt.line(to: NSPoint(x: ox + s * 0.2, y: oy - s * 0.8))
    bolt.line(to: NSPoint(x: ox - s * 0.15, y: oy + s * 0.05))
    bolt.line(to: NSPoint(x: ox + s * 0.05, y: oy + s * 0.05))
    bolt.close()

    // Glow effect
    NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.3, alpha: 0.6).setFill()
    bolt.fill()
    NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.5, alpha: 0.9).setFill()

    let boltInner = NSBezierPath()
    let inset: CGFloat = s * 0.05
    boltInner.move(to: NSPoint(x: ox - s * 0.2 + inset, y: oy + s * 1.2 - inset))
    boltInner.line(to: NSPoint(x: ox + s * 0.15 - inset, y: oy + s * 0.2 + inset))
    boltInner.line(to: NSPoint(x: ox - s * 0.05 + inset, y: oy + s * 0.2 + inset))
    boltInner.line(to: NSPoint(x: ox + s * 0.2 - inset, y: oy - s * 0.8 + inset))
    boltInner.line(to: NSPoint(x: ox - s * 0.15 + inset, y: oy + s * 0.05))
    boltInner.line(to: NSPoint(x: ox + s * 0.05 - inset, y: oy + s * 0.05))
    boltInner.close()
    boltInner.fill()
}

/// Draws subtle speed lines emanating from the fast zone.
func drawSpeedLines(centerX: CGFloat, centerY: CGFloat, gaugeRadius: CGFloat, size: CGFloat) {
    let lineAngles: [CGFloat] = [305, 315, 325]
    for (index, angle) in lineAngles.enumerated() {
        let radians = angle * .pi / 180.0
        let innerR = gaugeRadius + size * 0.06
        let outerR = gaugeRadius + size * 0.10 + CGFloat(index % 2) * size * 0.03

        let linePath = NSBezierPath()
        linePath.move(to: NSPoint(x: centerX + innerR * cos(radians),
                                   y: centerY + innerR * sin(radians)))
        linePath.line(to: NSPoint(x: centerX + outerR * cos(radians),
                                   y: centerY + outerR * sin(radians)))
        linePath.lineWidth = size * 0.012
        linePath.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.5 - CGFloat(index) * 0.1).setStroke()
        linePath.stroke()
    }
}

/// Draws a small label below the gauge.
func drawLabel(text: String, centerX: CGFloat, y: CGFloat, size: CGFloat) {
    let fontSize = size * 0.07
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white.withAlphaComponent(0.85),
        .kern: fontSize * 0.25
    ]
    let attrString = NSAttributedString(string: text, attributes: attributes)
    let stringSize = attrString.size()
    let drawPoint = NSPoint(x: centerX - stringSize.width / 2, y: y - stringSize.height / 2)
    attrString.draw(at: drawPoint)
}

/// Renders the icon at the specified pixel size and returns PNG data.
func renderIcon(pixelSize: Int) -> Data {
    let size = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.shouldAntialias = true
    drawIcon(size: size)
    image.unlockFocus()

    guard let tiffData = image.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to create PNG data for size \(pixelSize)")
    }
    return pngData
}

// MARK: - Main

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .deletingLastPathComponent() // go up from scripts/ if run from there

// Determine the actual project root (handle running from project root or scripts/)
let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0])
let resolvedRoot: URL
if FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("Package.swift").path) {
    resolvedRoot = projectRoot
} else {
    // Running from project root: swift scripts/generate-icon.swift
    resolvedRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

let resourcesDir = resolvedRoot.appendingPathComponent("Resources")
let iconsetDir = resourcesDir.appendingPathComponent("AppIcon.iconset")

// Create directories
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

print("Generating app icon for 'Make My Mac Fast Again'...")

// macOS icon sizes: each size has a @1x and @2x variant
// The .iconset folder expects these files:
//   icon_16x16.png, icon_16x16@2x.png (32px),
//   icon_32x32.png, icon_32x32@2x.png (64px),
//   icon_128x128.png, icon_128x128@2x.png (256px),
//   icon_256x256.png, icon_256x256@2x.png (512px),
//   icon_512x512.png, icon_512x512@2x.png (1024px)
let iconSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for entry in iconSizes {
    let pngData = renderIcon(pixelSize: entry.pixels)
    let fileURL = iconsetDir.appendingPathComponent(entry.name)
    try pngData.write(to: fileURL)
    print("  Generated \(entry.name) (\(entry.pixels)x\(entry.pixels) px)")
}

// Convert .iconset to .icns using iconutil
let icnsPath = resourcesDir.appendingPathComponent("AppIcon.icns")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]

let pipe = Pipe()
process.standardError = pipe

try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
    fatalError("iconutil failed: \(errorString)")
}

// Clean up the .iconset directory
try FileManager.default.removeItem(at: iconsetDir)

print("App icon created at: \(icnsPath.path)")
print("Done!")
