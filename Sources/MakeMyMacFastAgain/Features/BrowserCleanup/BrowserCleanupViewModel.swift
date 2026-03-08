import Foundation

@MainActor
@Observable
final class BrowserCleanupViewModel {
    var browsers: [BrowserProfile] = []
    var isScanning = false
    var isCleaning = false
    var statusMessage = ""
    var cleanCache = true
    var cleanCookies = false

    private let fileScanner = FileScanner()

    var totalCacheSize: UInt64 {
        browsers.filter(\.isInstalled).reduce(0) { $0 + $1.cacheSize }
    }

    func loadBrowsers() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

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
                cachePaths: [
                    "\(home)/Library/Caches/Google/Chrome",
                    "\(home)/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage"
                ],
                cookiePaths: [
                    "\(home)/Library/Application Support/Google/Chrome/Default/Cookies"
                ]
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
                cachePaths: [
                    "\(home)/Library/Caches/Microsoft Edge"
                ],
                cookiePaths: [
                    "\(home)/Library/Application Support/Microsoft Edge/Default/Cookies"
                ]
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
                cachePaths: [
                    "\(home)/Library/Caches/BraveSoftware/Brave-Browser"
                ],
                cookiePaths: [
                    "\(home)/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies"
                ]
            )
        ]

        // Detect installed browsers
        for i in browsers.indices {
            let hasCache = browsers[i].cachePaths.contains { FileManager.default.fileExists(atPath: $0) }
            browsers[i].isInstalled = hasCache
        }
    }

    func scanSizes() async {
        isScanning = true
        statusMessage = "Scanning browser caches..."

        for i in browsers.indices where browsers[i].isInstalled {
            var totalSize: UInt64 = 0
            for path in browsers[i].cachePaths {
                totalSize += await fileScanner.calculateDirectorySize(path)
            }
            browsers[i].cacheSize = totalSize
        }

        isScanning = false
        statusMessage = "Found \(ByteFormatter.format(totalCacheSize)) in browser caches."
    }

    func cleanBrowsers() async {
        isCleaning = true
        var freedSpace: UInt64 = 0

        for browser in browsers where browser.isInstalled && browser.cacheSize > 0 {
            statusMessage = "Cleaning \(browser.browser)..."

            if cleanCache {
                for path in browser.cachePaths {
                    freedSpace += removePath(path)
                }
            }

            if cleanCookies {
                for path in browser.cookiePaths {
                    freedSpace += removePath(path)
                }
            }
        }

        isCleaning = false
        statusMessage = "Freed \(ByteFormatter.format(freedSpace)) from browser data."
        await scanSizes()
    }

    private func removePath(_ path: String) -> UInt64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return 0 }

        do {
            let attrs = try fm.attributesOfItem(atPath: path)
            let size = attrs[.size] as? UInt64 ?? 0

            if (attrs[.type] as? FileAttributeType) == .typeDirectory {
                let contents = try fm.contentsOfDirectory(atPath: path)
                var totalFreed: UInt64 = 0
                for item in contents {
                    let itemPath = "\(path)/\(item)"
                    if let itemAttrs = try? fm.attributesOfItem(atPath: itemPath),
                       let itemSize = itemAttrs[.size] as? UInt64 {
                        totalFreed += itemSize
                    }
                    try fm.removeItem(atPath: itemPath)
                }
                return totalFreed
            } else {
                try fm.removeItem(atPath: path)
                return size
            }
        } catch {
            return 0
        }
    }
}
