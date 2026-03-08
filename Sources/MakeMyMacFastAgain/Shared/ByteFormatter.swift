import Foundation

enum ByteFormatter {
    static func format(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func formatRate(_ bytesPerSecond: Double) -> String {
        let absBytes = abs(bytesPerSecond)
        if absBytes < 1024 {
            return String(format: "%.0f B/s", absBytes)
        } else if absBytes < 1024 * 1024 {
            return String(format: "%.1f KB/s", absBytes / 1024)
        } else if absBytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", absBytes / (1024 * 1024))
        } else {
            return String(format: "%.2f GB/s", absBytes / (1024 * 1024 * 1024))
        }
    }

    static func formatPercentage(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}
