import Foundation
import AppKit
import os

struct FileTypeBreakdown: Identifiable, Sendable {
    let id = UUID()
    let type: String
    let count: Int
    let totalSize: UInt64
}

@MainActor
@Observable
final class LargeFileFinderViewModel {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "large-file-finder")
    var files: [LargeFile] = []
    var isScanning = false
    var filesScanned = 0
    var currentPath = ""
    var statusMessage = ""
    var selectedMinSize: MinFileSize = .mb100
    var selectedFileIDs: Set<UUID> = []

    private let fileScanner = FileScanner()
    private var scanTask: Task<Void, Never>?

    enum MinFileSize: String, CaseIterable {
        case mb50 = "50 MB"
        case mb100 = "100 MB"
        case mb500 = "500 MB"
        case gb1 = "1 GB"

        var bytes: UInt64 {
            switch self {
            case .mb50: return 50 * 1024 * 1024
            case .mb100: return 100 * 1024 * 1024
            case .mb500: return 500 * 1024 * 1024
            case .gb1: return 1024 * 1024 * 1024
            }
        }
    }

    private static let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv"]
    private static let diskImageExtensions: Set<String> = ["dmg", "iso", "img"]
    private static let archiveExtensions: Set<String> = ["zip", "tar", "gz", "rar", "7z"]
    private static let applicationExtensions: Set<String> = ["app"]
    private static let documentExtensions: Set<String> = ["pdf", "docx", "xlsx"]

    /// Groups files by extension category and returns a breakdown sorted by total size descending.
    var typeBreakdown: [FileTypeBreakdown] {
        var groups: [String: (count: Int, totalSize: UInt64)] = [:]

        for file in files {
            let ext = (file.name as NSString).pathExtension.lowercased()
            let category = Self.extensionCategory(ext)

            let existing = groups[category, default: (count: 0, totalSize: 0)]
            groups[category] = (count: existing.count + 1, totalSize: existing.totalSize + file.size)
        }

        return groups.map { FileTypeBreakdown(type: $0.key, count: $0.value.count, totalSize: $0.value.totalSize) }
            .sorted { $0.totalSize > $1.totalSize }
    }

    /// Total size of all found files.
    var totalFilesSize: UInt64 {
        files.reduce(0) { $0 + $1.size }
    }

    var selectedFiles: [LargeFile] {
        files.filter { selectedFileIDs.contains($0.id) }
    }

    var totalSelectedSize: UInt64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }

    private static func extensionCategory(_ ext: String) -> String {
        if videoExtensions.contains(ext) { return "Videos" }
        if diskImageExtensions.contains(ext) { return "Disk Images" }
        if archiveExtensions.contains(ext) { return "Archives" }
        if applicationExtensions.contains(ext) { return "Applications" }
        if documentExtensions.contains(ext) { return "Documents" }
        return "Other"
    }

    func scan() async {
        isScanning = true
        files = []
        selectedFileIDs = []
        filesScanned = 0
        statusMessage = "Scanning..."

        scanTask = Task {
            let home = FileManager.default.homeDirectoryForCurrentUser.path

            let result = await fileScanner.scanForLargeFiles(
                in: home,
                minSize: selectedMinSize.bytes
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.filesScanned = progress.filesScanned
                    self?.currentPath = progress.currentPath
                }
            }

            guard !Task.isCancelled else { return }

            files = result
            isScanning = false
            statusMessage = "Found \(files.count) files larger than \(selectedMinSize.rawValue)."
        }
        await scanTask?.value
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        statusMessage = "Scan cancelled"
    }

    func moveToTrash() async {
        var trashed = 0
        var freedSpace: UInt64 = 0

        for file in selectedFiles {
            let url = URL(fileURLWithPath: file.path)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                freedSpace += file.size
                trashed += 1
            } catch {
                logger.warning("Failed to trash \(file.name, privacy: .public) at \(file.path, privacy: .private): \(error.localizedDescription)")
                statusMessage = "Failed to trash \(file.name): \(error.localizedDescription)"
            }
        }

        files.removeAll { selectedFileIDs.contains($0.id) }
        selectedFileIDs.removeAll()
        statusMessage = "Moved \(trashed) files (\(ByteFormatter.format(freedSpace))) to Trash."
    }

    func revealInFinder(_ file: LargeFile) {
        NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
    }
}
