import AppKit
import Foundation
import UserNotifications
import os

/// Manages macOS local notifications for system health alerts and cleanup results.
///
/// Uses `UNUserNotificationCenter` to post grouped notifications with a per-type
/// throttle (5 minutes) so the user is never spammed by repeated alerts from the
/// periodic refresh timer.
@MainActor
final class NotificationService: NSObject {
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "notifications")

    /// Lazily initialized — UNUserNotificationCenter.current() crashes if the app
    /// has no proper bundle (e.g. running as a bare debug binary from `swift run`).
    private var center: UNUserNotificationCenter?

    /// Whether setup has been attempted.
    private var isSetUp = false

    /// Tracks the last time each notification category was posted, keyed by category identifier.
    private var lastNotificationTimes: [String: Date] = [:]

    /// Minimum interval between notifications of the same type (seconds).
    private let throttleInterval: TimeInterval = 300 // 5 minutes

    // MARK: - Category Identifiers

    private enum Category {
        static let highMemory = "HIGH_MEMORY_PRESSURE"
        static let lowDisk = "LOW_DISK_SPACE"
        static let cleanupComplete = "CLEANUP_COMPLETE"
    }

    // MARK: - Init

    override init() {
        super.init()
    }

    /// Lazily sets up the notification center on first use. Returns false if
    /// UNUserNotificationCenter is unavailable (no bundle).
    private func setUp() -> Bool {
        guard !isSetUp else { return center != nil }
        isSetUp = true

        // UNUserNotificationCenter.current() requires a valid bundle proxy.
        // When running from `swift run` (bare binary) this will crash, so we
        // guard with Bundle.main.bundleIdentifier.
        guard Bundle.main.bundleIdentifier != nil else {
            logger.warning("No bundle identifier — notifications unavailable (running outside .app bundle)")
            return false
        }

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        self.center = notificationCenter
        requestAuthorization()
        registerCategories()
        return true
    }

    // MARK: - Authorization

    private func requestAuthorization() {
        guard let center else { return }
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                if granted {
                    logger.info("Notification authorization granted")
                } else {
                    logger.info("Notification authorization denied by user")
                }
            } catch {
                logger.error("Failed to request notification authorization: \(error.localizedDescription)")
            }
        }
    }

    /// Registers notification categories so the system can group them.
    private func registerCategories() {
        guard let center else { return }
        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(identifier: Category.highMemory, actions: [], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.lowDisk, actions: [], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.cleanupComplete, actions: [], intentIdentifiers: []),
        ]
        center.setNotificationCategories(categories)
    }

    // MARK: - Public API

    /// Posts a notification warning the user about high memory pressure.
    func notifyHighMemoryPressure() {
        scheduleNotification(
            category: Category.highMemory,
            title: "High Memory Pressure",
            body: "Memory pressure is high. Consider freeing memory."
        )
    }

    /// Posts a notification warning the user about low disk space.
    func notifyDiskSpaceLow(freeSpace: UInt64) {
        let formatted = ByteFormatter.format(freeSpace)
        scheduleNotification(
            category: Category.lowDisk,
            title: "Low Disk Space",
            body: "Disk space is low: \(formatted) free. Consider cleaning caches."
        )
    }

    /// Posts a notification confirming a cleanup operation completed.
    func notifyCleanupComplete(freedBytes: UInt64) {
        let formatted = ByteFormatter.format(freedBytes)
        scheduleNotification(
            category: Category.cleanupComplete,
            title: "Cleanup Complete",
            body: "Cleanup complete! Freed \(formatted)."
        )
    }

    // MARK: - Private

    /// Schedules a local notification, respecting the per-category throttle.
    private func scheduleNotification(category: String, title: String, body: String) {
        guard setUp(), let center else { return }

        guard !isThrottled(category: category) else {
            logger.debug("Notification throttled for category: \(category)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category

        // Fire immediately (nil trigger = deliver right away)
        let request = UNNotificationRequest(
            identifier: "\(category)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { [weak self] error in
            if let error {
                // Logger capture must happen on MainActor; fire-and-forget is fine here.
                Task { @MainActor in
                    self?.logger.error("Failed to schedule notification: \(error.localizedDescription)")
                }
            }
        }

        lastNotificationTimes[category] = Date()
    }

    /// Returns `true` if a notification for the given category was posted within the throttle window.
    private func isThrottled(category: String) -> Bool {
        guard let lastTime = lastNotificationTimes[category] else {
            return false
        }
        return Date().timeIntervalSince(lastTime) < throttleInterval
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Called when a notification arrives while the app is in the foreground.
    /// We still display it as a banner so the user sees the alert.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Called when the user taps/clicks on a delivered notification.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Bring the app to the foreground when the notification is clicked.
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
        }
        completionHandler()
    }
}
