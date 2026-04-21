import AppKit
import SwiftUI
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "app")
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var statusBarController: StatusBarController?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application did finish launching")
        let contentView = ContentView()
            .environment(\.appState, appState)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Make My Mac Fast Again"
        window.minSize = NSSize(width: 800, height: 500)
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        // Without this, AppKit releases the NSWindow when the user closes it;
        // the stored `self.window` then points to freed memory and
        // `showMainWindow()` (called from the menubar popover) segfaults on
        // the next open. Settings and About windows already do this.
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        appState.startMonitoring()
        statusBarController = StatusBarController(appState: appState)
        setupMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showMainWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Make My Mac Fast Again", action: #selector(openAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Make My Mac Fast Again", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (for text fields)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func openAbout() {
        if let aboutWindow {
            aboutWindow.makeKeyAndOrderFront(nil)
            return
        }

        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        aboutWindow.title = "About Make My Mac Fast Again"
        aboutWindow.contentView = NSHostingView(rootView: AboutView())
        aboutWindow.center()
        aboutWindow.makeKeyAndOrderFront(nil)
        aboutWindow.isReleasedWhenClosed = false

        self.aboutWindow = aboutWindow
    }

    @objc private func openSettings() {
        if let settingsWindow = settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Settings"
        settingsWindow.contentView = NSHostingView(rootView: SettingsView().environment(\.appState, appState))
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
        settingsWindow.isReleasedWhenClosed = false

        self.settingsWindow = settingsWindow
    }
}
