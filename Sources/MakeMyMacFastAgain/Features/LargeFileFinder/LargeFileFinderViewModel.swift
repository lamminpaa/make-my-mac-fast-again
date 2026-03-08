import Foundation
import AppKit

@MainActor
@Observable
final class LargeFileFinderViewModel {
    var files: [LargeFile] = []
    var isScanning = false
    var filesScanned = 0
    var currentPath = ""
    var statusMessage = ""
    var selectedMinSize: MinFileSize = .mb100
    var selectedFileIDs: Set<UUID> = []

    private let fileScanner = FileScanner()

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

    var selectedFiles: [LargeFile] {
        files.filter { selectedFileIDs.contains($0.id) }
    }

    var totalSelectedSize: UInt64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }

    func scan() async {
        isScanning = true
        files = []
        selectedFileIDs = []
        filesScanned = 0
        statusMessage = "Scanning..."

        let home = FileManager.default.homeDirectoryForCurrentUser.path

        files = await fileScanner.scanForLargeFiles(
            in: home,
            minSize: selectedMinSize.bytes
        ) { [weak self] progress in
            Task { @MainActor in
                self?.filesScanned = progress.filesScanned
                self?.currentPath = progress.currentPath
            }
        }

        isScanning = false
        statusMessage = "Found \(files.count) files larger than \(selectedMinSize.rawValue)."
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
