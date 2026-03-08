import Foundation

actor FileScanner {
    struct ScanProgress: Sendable {
        var filesScanned: Int
        var largeFilesFound: Int
        var currentPath: String
    }

    func scanForLargeFiles(
        in directory: String,
        minSize: UInt64,
        onProgress: @Sendable @escaping (ScanProgress) -> Void
    ) async -> [LargeFile] {
        let results = _scanForLargeFiles(in: directory, minSize: minSize, onProgress: onProgress)
        return results.sorted { $0.size > $1.size }
    }

    private nonisolated func _scanForLargeFiles(
        in directory: String,
        minSize: UInt64,
        onProgress: @Sendable (ScanProgress) -> Void
    ) -> [LargeFile] {
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

        for case let fileURL as URL in enumerator {
            progress.filesScanned += 1

            if progress.filesScanned % 500 == 0 {
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

        return results
    }

    func calculateDirectorySize(_ path: String) async -> UInt64 {
        _calculateDirectorySize(path)
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

        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += UInt64(size)
            }
        }

        return totalSize
    }
}
