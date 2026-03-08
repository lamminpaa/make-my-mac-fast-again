import Foundation

struct DNSServerInfo: Sendable {
    let resolver: String
    let servers: [String]
    let domain: String?
}

@MainActor
@Observable
final class DNSFlushViewModel {
    var isFlushing = false
    var statusMessage = ""
    var lastFlushDate: Date?
    var flushSucceeded: Bool?
    var dnsServers: [DNSServerInfo] = []
    var isLoadingDNS = false

    private let privilegedExecutor = PrivilegedExecutor()
    private let shell = ShellExecutor()

    func loadDNSInfo() async {
        isLoadingDNS = true
        defer { isLoadingDNS = false }

        do {
            let result = try await shell.run("scutil --dns")
            dnsServers = parseDNSOutput(result.output)
        } catch {
            dnsServers = []
        }
    }

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

    private func parseDNSOutput(_ output: String) -> [DNSServerInfo] {
        var results: [DNSServerInfo] = []
        var currentResolver = ""
        var currentServers: [String] = []
        var currentDomain: String?

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("resolver #") {
                if !currentResolver.isEmpty && !currentServers.isEmpty {
                    results.append(DNSServerInfo(
                        resolver: currentResolver,
                        servers: currentServers,
                        domain: currentDomain
                    ))
                }
                currentResolver = trimmed
                currentServers = []
                currentDomain = nil
            } else if trimmed.hasPrefix("nameserver[") {
                if let colonIdx = trimmed.firstIndex(of: ":") {
                    let server = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    currentServers.append(server)
                }
            } else if trimmed.hasPrefix("domain   :") {
                currentDomain = String(trimmed.dropFirst("domain   :".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("search domain[") {
                if let colonIdx = trimmed.firstIndex(of: ":") {
                    let domain = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    if currentDomain == nil {
                        currentDomain = domain
                    }
                }
            }
        }

        // Don't forget last resolver
        if !currentResolver.isEmpty && !currentServers.isEmpty {
            results.append(DNSServerInfo(
                resolver: currentResolver,
                servers: currentServers,
                domain: currentDomain
            ))
        }

        return results
    }
}
