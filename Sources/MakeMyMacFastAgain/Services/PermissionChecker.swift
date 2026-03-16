import Foundation

struct PermissionChecker: Sendable {
    /// Checks if the app has Full Disk Access by trying to read a protected file.
    static func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // Safari bookmarks require FDA to read
        let testPath = home.appendingPathComponent("Library/Safari/Bookmarks.plist")
        return FileManager.default.isReadableFile(atPath: testPath.path)
    }
}
