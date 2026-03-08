import Foundation

@MainActor
@Observable
final class DNSFlushViewModel {
    var isFlushing = false
    var statusMessage = ""
    var lastFlushDate: Date?
    var flushSucceeded: Bool?

    private let privilegedExecutor = PrivilegedExecutor()

    func flushDNS() async {
        isFlushing = true
        statusMessage = "Flushing DNS cache (requires admin)..."
        flushSucceeded = nil

        do {
            _ = try await privilegedExecutor.run("killall -HUP mDNSResponder")
            flushSucceeded = true
            lastFlushDate = Date()
            statusMessage = "DNS cache flushed successfully."
        } catch {
            flushSucceeded = false
            statusMessage = "DNS flush failed: \(error.localizedDescription)"
        }

        isFlushing = false
    }
}
