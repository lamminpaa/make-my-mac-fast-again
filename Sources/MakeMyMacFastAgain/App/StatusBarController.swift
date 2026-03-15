import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover

    init(appState: AppState) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()

        let popoverContent = StatusBarPopover()
            .environment(\.appState, appState)

        popover.contentSize = NSSize(width: 280, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: popoverContent)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "gauge.with.dots.needle.33percent",
                accessibilityDescription: "Make My Mac Fast Again"
            )
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ensure the popover window becomes key so it can receive focus
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
