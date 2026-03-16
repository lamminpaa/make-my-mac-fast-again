import Foundation
import AppKit
import os

@MainActor
@Observable
final class BrowserCleanupViewModel {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "browser-cleanup")
    var browsers: [BrowserProfile] = []
    var isScanning = false
    var isCleaning = false
    var statusMessage = ""
    var cleanCache = true
    var cleanCookies = false

    /// Set by the view to enable cleanup-complete notifications.
    var notificationService: NotificationService?

    private weak var appState: AppState?
    private let fileScanner = FileScanner()

    func bind(to appState: AppState) {
        self.appState = appState
        self.notificationService = appState.notificationService
    }

    var totalCacheSize: UInt64 {
        browsers.filter(\.isInstalled).reduce(0) { $0 + $1.cacheSize }
    }

    /// Checks whether a browser is currently running by matching its name against running applications.
    func isBrowserRunning(_ browser: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        let bundleIdentifierMap: [String: [String]] = [
            "Safari": ["com.apple.Safari"],
            "Google Chrome": ["com.google.Chrome"],
            "Firefox": ["org.mozilla.firefox"],
            "Microsoft Edge": ["com.microsoft.edgemac"],
            "Arc": ["company.thebrowser.Browser"],
            "Brave": ["com.brave.Browser"]
        ]

        guard let identifiers = bundleIdentifierMap[browser] else { return false }

        return runningApps.contains { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return identifiers.contains(bundleID)
        }
    }

    func loadBrowsers() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let chromeCachePaths = chromiumProfilePaths(
            appSupportDir: "\(home)/Library/Application Support/Google/Chrome",
            cacheDir: "\(home)/Library/Caches/Google/Chrome",
            subpath: "Service Worker/CacheStorage"
        )

        let edgeCachePaths = chromiumProfilePaths(
            appSupportDir: "\(home)/Library/Application Support/Microsoft Edge",
            cacheDir: "\(home)/Library/Caches/Microsoft Edge",
            subpath: "Service Worker/CacheStorage"
        )

        let braveCachePaths = chromiumProfilePaths(
            appSupportDir: "\(home)/Library/Application Support/BraveSoftware/Brave-Browser",
            cacheDir: "\(home)/Library/Caches/BraveSoftware/Brave-Browser",
            subpath: "Service Worker/CacheStorage"
        )

        browsers = [
            BrowserProfile(
                browser: "Safari",
                cachePaths: [
                    "\(home)/Library/Caches/com.apple.Safari",
                    "\(home)/Library/Caches/com.apple.Safari.SafeBrowsing"
                ],
                cookiePaths: [
                    "\(home)/Library/Cookies/Cookies.binarycookies"
                ]
            ),
            BrowserProfile(
                browser: "Google Chrome",
                cachePaths: ["\(home)/Library/Caches/Google/Chrome"] + chromeCachePaths.cache,
                cookiePaths: chromeCachePaths.cookies
            ),
            BrowserProfile(
                browser: "Firefox",
                cachePaths: [
                    "\(home)/Library/Caches/Firefox"
                ],
                cookiePaths: []
            ),
            BrowserProfile(
                browser: "Microsoft Edge",
                cachePaths: ["\(home)/Library/Caches/Microsoft Edge"] + edgeCachePaths.cache,
                cookiePaths: edgeCachePaths.cookies
            ),
            BrowserProfile(
                browser: "Arc",
                cachePaths: [
                    "\(home)/Library/Caches/company.thebrowser.Browser"
                ],
                cookiePaths: []
            ),
            BrowserProfile(
                browser: "Brave",
                cachePaths: ["\(home)/Library/Caches/BraveSoftware/Brave-Browser"] + braveCachePaths.cache,
                cookiePaths: braveCachePaths.cookies
            )
        ]

        // Detect installed browsers
        for i in browsers.indices {
            let hasCache = browsers[i].cachePaths.contains { FileManager.default.fileExists(atPath: $0) }
            browsers[i].isInstalled = hasCache
        }
    }

    /// Discovers all Chromium profile directories (Default, Profile 1, Profile 2, etc.)
    /// and returns their cache and cookie paths.
    private func chromiumProfilePaths(
        appSupportDir: String,
        cacheDir: String?,
        subpath: String
    ) -> (cache: [String], cookies: [String]) {
        let fm = FileManager.default
        var cachePaths: [String] = []
        var cookiePaths: [String] = []

        guard fm.fileExists(atPath: appSupportDir) else {
            return (cache: [], cookies: [])
        }

        do {
            let contents = try fm.contentsOfDirectory(atPath: appSupportDir)
            let profileDirs = contents.filter { $0 == "Default" || $0.hasPrefix("Profile ") }

            for profile in profileDirs {
                let profilePath = "\(appSupportDir)/\(profile)"
                let cacheStoragePath = "\(profilePath)/\(subpath)"
                if fm.fileExists(atPath: cacheStoragePath) {
                    cachePaths.append(cacheStoragePath)
                }
                let cookiesPath = "\(profilePath)/Cookies"
                if fm.fileExists(atPath: cookiesPath) {
                    cookiePaths.append(cookiesPath)
                }
            }
        } catch {
            // Fall back to Default profile only
            let defaultCache = "\(appSupportDir)/Default/\(subpath)"
            if fm.fileExists(atPath: defaultCache) {
                cachePaths.append(defaultCache)
            }
            let defaultCookies = "\(appSupportDir)/Default/Cookies"
            if fm.fileExists(atPath: defaultCookies) {
                cookiePaths.append(defaultCookies)
            }
        }

        return (cache: cachePaths, cookies: cookiePaths)
    }

    func scanSizes() async {
        isScanning = true
        statusMessage = "Scanning browser caches..."

        let installedIndices = browsers.indices.filter { browsers[$0].isInstalled }
        let results = await withTaskGroup(
            of: (index: Int, size: UInt64).self,
            returning: [(index: Int, size: UInt64)].self
        ) { group in
            for i in installedIndices {
                let paths = browsers[i].cachePaths
                group.addTask { [fileScanner] in
                    var size: UInt64 = 0
                    for path in paths {
                        size += await fileScanner.calculateDirectorySize(path)
                    }
                    return (index: i, size: size)
                }
            }
            var collected: [(index: Int, size: UInt64)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        for result in results {
            browsers[result.index].cacheSize = result.size
        }

        isScanning = false
        statusMessage = "Found \(ByteFormatter.format(totalCacheSize)) in browser caches."
    }

    /// Returns names of installed browsers with cache data that are currently running.
    var runningBrowsersWithData: [String] {
        browsers.filter { $0.isInstalled && $0.cacheSize > 0 && isBrowserRunning($0.browser) }
            .map(\.browser)
    }

    func cleanBrowsers() async {
        isCleaning = true
        var freedSpace: UInt64 = 0
        var skippedBrowsers: [String] = []

        for browser in browsers where browser.isInstalled && browser.cacheSize > 0 {
            // Skip running browsers to prevent data corruption
            if isBrowserRunning(browser.browser) {
                skippedBrowsers.append(browser.browser)
                continue
            }
            statusMessage = "Cleaning \(browser.browser)..."

            if cleanCache {
                for path in browser.cachePaths {
                    freedSpace += await removePath(path)
                }
            }

            if cleanCookies {
                for path in browser.cookiePaths {
                    freedSpace += await removePath(path)
                }
            }
        }

        await fileScanner.invalidateCache()

        isCleaning = false
        var message = "Freed \(ByteFormatter.format(freedSpace)) from browser data."
        if !skippedBrowsers.isEmpty {
            message += " Skipped \(skippedBrowsers.joined(separator: ", ")) (still running)."
        }
        statusMessage = message

        if freedSpace > 0 {
            var settings = AppSettings.load()
            settings.recordCleanup(freedBytes: freedSpace)
            notificationService?.notifyCleanupComplete(freedBytes: freedSpace)
        }

        await scanSizes()
    }

    private func removePath(_ path: String) async -> UInt64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return 0 }

        let sizeBefore = await fileScanner.calculateDirectorySize(path)

        do {
            let attrs = try fm.attributesOfItem(atPath: path)

            if (attrs[.type] as? FileAttributeType) == .typeDirectory {
                let contents = try fm.contentsOfDirectory(atPath: path)
                for item in contents {
                    try? fm.removeItem(atPath: "\(path)/\(item)")
                }
            } else {
                try fm.removeItem(atPath: path)
            }
        } catch {
            logger.warning("Failed to clean \(path, privacy: .private): \(error.localizedDescription)")
        }

        let sizeAfter = await fileScanner.calculateDirectorySize(path)
        return sizeBefore > sizeAfter ? sizeBefore - sizeAfter : 0
    }
}
