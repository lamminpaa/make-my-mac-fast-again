import Foundation
import SwiftUI

@MainActor
@Observable
final class CacheCleanerViewModel {
    var categories: [CacheCategory] = []
    var isScanning = false
    var isCleaning = false
    var statusMessage = ""

    private let fileScanner = FileScanner()
    private let shell = ShellExecutor()
    private let privilegedExecutor = PrivilegedExecutor()

    var totalSelectedSize: UInt64 {
        categories.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var totalSize: UInt64 {
        categories.reduce(0) { $0 + $1.size }
    }

    func loadCategories() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        categories = [
            CacheCategory(
                name: "User Caches",
                description: "Application caches in ~/Library/Caches",
                paths: ["\(home)/Library/Caches"],
                requiresAdmin: false
            ),
            CacheCategory(
                name: "System Caches",
                description: "System-level caches in /Library/Caches",
                paths: ["/Library/Caches"],
                requiresAdmin: true
            ),
            CacheCategory(
                name: "Xcode Derived Data",
                description: "Xcode build artifacts",
                paths: ["\(home)/Library/Developer/Xcode/DerivedData"],
                requiresAdmin: false
            ),
            CacheCategory(
                name: "Xcode Archives",
                description: "Old Xcode archive builds",
                paths: ["\(home)/Library/Developer/Xcode/Archives"],
                requiresAdmin: false
            ),
            CacheCategory(
                name: "Homebrew Cache",
                description: "Downloaded Homebrew packages",
                paths: ["\(home)/Library/Caches/Homebrew"],
                requiresAdmin: false
            ),
            CacheCategory(
                name: "CocoaPods Cache",
                description: "CocoaPods download cache",
                paths: ["\(home)/Library/Caches/CocoaPods"],
                requiresAdmin: false
            ),
            CacheCategory(
                name: "npm Cache",
                description: "Node.js package manager cache",
                paths: ["\(home)/.npm/_cacache"],
                requiresAdmin: false
            ),
            CacheCategory(
                name: "Logs",
                description: "Application logs in ~/Library/Logs",
                paths: ["\(home)/Library/Logs"],
                requiresAdmin: false
            )
        ]
    }

    func scanSizes() async {
        isScanning = true
        statusMessage = "Scanning cache sizes..."

        for i in categories.indices {
            var totalSize: UInt64 = 0
            for path in categories[i].paths {
                totalSize += await fileScanner.calculateDirectorySize(path)
            }
            categories[i].size = totalSize
        }

        isScanning = false
        statusMessage = "Scan complete. Found \(ByteFormatter.format(totalSize)) in caches."
    }

    func cleanSelected() async {
        isCleaning = true
        var freedSpace: UInt64 = 0

        let selectedCategories = categories.filter { $0.isSelected && $0.size > 0 }

        for category in selectedCategories {
            statusMessage = "Cleaning \(category.name)..."

            for path in category.paths {
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: path) else { continue }

                if category.requiresAdmin {
                    do {
                        _ = try await privilegedExecutor.run("rm -rf '\(path)'/*")
                        freedSpace += category.size
                    } catch {
                        statusMessage = "Failed to clean \(category.name): \(error.localizedDescription)"
                    }
                } else {
                    do {
                        let contents = try fileManager.contentsOfDirectory(atPath: path)
                        for item in contents {
                            let itemPath = "\(path)/\(item)"
                            try fileManager.removeItem(atPath: itemPath)
                        }
                        freedSpace += category.size
                    } catch {
                        statusMessage = "Failed to clean \(category.name): \(error.localizedDescription)"
                    }
                }
            }
        }

        isCleaning = false
        statusMessage = "Freed \(ByteFormatter.format(freedSpace))."

        await scanSizes()
    }
}
