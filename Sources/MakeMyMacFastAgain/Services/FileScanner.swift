import Foundation

actor FileScanner {
    struct ScanProgress: Sendable {
        var filesScanned: Int
        var largeFilesFound: Int
        var currentPath: String
    }

    private struct CacheEntry {
        let size: UInt64
        let timestamp: Date
    }

    private static let cacheTTL: TimeInterval = 30

    private var sizeCache: [String: CacheEntry] = [:]

    func invalidateCache() {
        sizeCache.removeAll()
    }

    func invalidateCache(for path: String) {
        sizeCache.removeValue(forKey: path)
    }

    func scanForLargeFiles(
        in directory: String,
        minSize: UInt64,
        onProgress: @Sendable @escaping (ScanProgress) -> Void
    ) async -> [LargeFile] {
        var results: [LargeFile] = []
        var progress = ScanProgress(filesScanned: 0, largeFilesFound: 0, currentPath: "")

        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directory)

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return results
        }

        while let obj = enumerator.nextObject() {
            guard let fileURL = obj as? URL else { continue }
            if Task.isCancelled { break }

            progress.filesScanned += 1

            if progress.filesScanned % 100 == 0 {
                await Task.yield()
                progress.currentPath = fileURL.lastPathComponent
                onProgress(progress)
            }

            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  UInt64(size) >= minSize else {
                continue
            }

            let modDate = values.contentModificationDate ?? Date.distantPast

            results.append(LargeFile(
                path: fileURL.path,
                name: fileURL.lastPathComponent,
                size: UInt64(size),
                modifiedDate: modDate
            ))

            progress.largeFilesFound += 1
        }

        progress.currentPath = "Scan complete"
        onProgress(progress)

        return results.sorted { $0.size > $1.size }
    }

    func calculateDirectorySize(_ path: String) async -> UInt64 {
        if let cached = sizeCache[path],
           Date().timeIntervalSince(cached.timestamp) < Self.cacheTTL {
            return cached.size
        }

        let size = _calculateDirectorySize(path)
        sizeCache[path] = CacheEntry(size: size, timestamp: Date())
        return size
    }

    private nonisolated func _calculateDirectorySize(_ path: String) -> UInt64 {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
        ) else {
            return 0
        }

        var totalSize: UInt64 = 0
        var fileCount = 0

        for case let fileURL as URL in enumerator {
            fileCount += 1
            if fileCount % 100 == 0 && Task.isCancelled {
                break
            }
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += UInt64(size)
            }
        }

        return totalSize
    }
}
