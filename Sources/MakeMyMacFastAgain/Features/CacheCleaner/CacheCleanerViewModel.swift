import Foundation
import SwiftUI

@MainActor
@Observable
final class CacheCleanerViewModel {
    var categories: [CacheCategory] = []
    var isScanning = false
    var isCleaning = false
    var statusMessage = ""

    /// Subdirectory details per category name: maps category name to its top subdirectories with sizes.
    var categoryDetails: [String: [(name: String, size: UInt64)]] = [:]

    /// File count per category name.
    var fileCount: [String: Int] = [:]

    private let fileScanner = FileScanner()
    private let shell = ShellExecutor()
    private let privilegedExecutor = PrivilegedExecutor()
    private var scanTask: Task<Void, Never>?

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
                isSelected: false,
                requiresAdmin: false
            ),
            CacheCategory(
                name: "System Caches",
                description: "System-level caches in /Library/Caches",
                paths: ["/Library/Caches"],
                isSelected: false,
                requiresAdmin: true
            ),
            CacheCategory(
                name: "Xcode Derived Data",
                description: "Xcode build artifacts",
                paths: ["\(home)/Library/Developer/Xcode/DerivedData"],
                isSelected: false,
                requiresAdmin: false
            ),
            CacheCategory(
                name: "Xcode Archives",
                description: "Old Xcode archive builds",
                paths: ["\(home)/Library/Developer/Xcode/Archives"],
                isSelected: false,
                requiresAdmin: false
            ),
            CacheCategory(
                name: "Homebrew Cache",
                description: "Downloaded Homebrew packages",
                paths: ["\(home)/Library/Caches/Homebrew"],
                isSelected: false,
                requiresAdmin: false
            ),
            CacheCategory(
                name: "CocoaPods Cache",
                description: "CocoaPods download cache",
                paths: ["\(home)/Library/Caches/CocoaPods"],
                isSelected: false,
                requiresAdmin: false
            ),
            CacheCategory(
                name: "npm Cache",
                description: "Node.js package manager cache",
                paths: ["\(home)/.npm/_cacache"],
                isSelected: false,
                requiresAdmin: false
            ),
            CacheCategory(
                name: "Logs",
                description: "Application logs in ~/Library/Logs",
                paths: ["\(home)/Library/Logs"],
                isSelected: false,
                requiresAdmin: false
            )
        ]
    }

    func scanSizes() async {
        isScanning = true
        statusMessage = "Scanning cache sizes..."

        scanTask = Task {
            for i in categories.indices {
                guard !Task.isCancelled else { return }
                var totalSize: UInt64 = 0
                for path in categories[i].paths {
                    totalSize += await fileScanner.calculateDirectorySize(path)
                }
                categories[i].size = totalSize
            }

            guard !Task.isCancelled else { return }

            isScanning = false
            statusMessage = "Scan complete. Found \(ByteFormatter.format(totalSize)) in caches."
        }
        await scanTask?.value
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        statusMessage = "Scan cancelled"
    }

    /// Loads the top subdirectories (up to 5) for a given category, sorted by size descending.
    func loadCategoryDetails(for index: Int) async {
        guard index >= 0, index < categories.count else { return }

        let category = categories[index]
        let fm = FileManager.default
        var subdirectories: [(name: String, size: UInt64)] = []
        var totalFileCount = 0

        for path in category.paths {
            guard fm.fileExists(atPath: path) else { continue }

            guard let contents = try? fm.contentsOfDirectory(atPath: path) else { continue }
            totalFileCount += contents.count

            for item in contents {
                let itemPath = "\(path)/\(item)"
                let itemSize = await fileScanner.calculateDirectorySize(itemPath)
                subdirectories.append((name: item, size: itemSize))
            }
        }

        // Sort by size descending and keep top 5
        subdirectories.sort { $0.size > $1.size }
        let topSubdirectories = Array(subdirectories.prefix(5))

        categoryDetails[category.name] = topSubdirectories
        fileCount[category.name] = totalFileCount
    }

    func selectAll() {
        for i in categories.indices { categories[i].isSelected = true }
    }

    func deselectAll() {
        for i in categories.indices { categories[i].isSelected = false }
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

                let sizeBefore = await fileScanner.calculateDirectorySize(path)

                if category.requiresAdmin {
                    do {
                        _ = try await privilegedExecutor.run("rm -rf '\(path)'/*")
                    } catch {
                        statusMessage = "Failed to clean \(category.name): \(error.localizedDescription)"
                    }
                } else {
                    let contents = (try? fileManager.contentsOfDirectory(atPath: path)) ?? []
                    for item in contents {
                        let itemPath = "\(path)/\(item)"
                        try? fileManager.removeItem(atPath: itemPath)
                    }
                }

                let sizeAfter = await fileScanner.calculateDirectorySize(path)
                freedSpace += sizeBefore > sizeAfter ? sizeBefore - sizeAfter : 0
            }
        }

        isCleaning = false
        statusMessage = "Freed \(ByteFormatter.format(freedSpace))."

        // Clear cached details since contents changed
        categoryDetails.removeAll()
        fileCount.removeAll()

        await scanSizes()
    }
}
