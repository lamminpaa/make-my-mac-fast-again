import Foundation

struct DNSServerInfo: Sendable {
    let resolver: String
    let servers: [String]
    let domain: String?
}

struct DNSPreset: Sendable {
    let name: String
    let server: String
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
    var serverLatencies: [String: String] = [:]
    var isTestingServers = false

    let dnsPresets: [DNSPreset] = [
        DNSPreset(name: "Cloudflare", server: "1.1.1.1"),
        DNSPreset(name: "Google", server: "8.8.8.8"),
        DNSPreset(name: "OpenDNS", server: "208.67.222.222"),
    ]

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

    func testDNSServers() async {
        isTestingServers = true
        serverLatencies = [:]

        // Collect all unique server IPs from current config and presets
        var serversToTest = Set<String>()
        for info in dnsServers {
            for server in info.servers {
                serversToTest.insert(server)
            }
        }
        for preset in dnsPresets {
            serversToTest.insert(preset.server)
        }

        for server in serversToTest {
            do {
                let result = try await shell.run("ping -c 1 -t 2 \(server)")
                // Parse round-trip time from ping output
                // Example line: "round-trip min/avg/max/stddev = 1.234/1.234/1.234/0.000 ms"
                if let rtLine = result.output.components(separatedBy: "\n").last(where: { $0.contains("round-trip") }) {
                    let parts = rtLine.components(separatedBy: "=")
                    if parts.count >= 2 {
                        let values = parts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: "/")
                        if values.count >= 2 {
                            // Use the avg value (second field)
                            let avgMs = values[1].trimmingCharacters(in: .whitespaces)
                            if let ms = Double(avgMs) {
                                serverLatencies[server] = String(format: "%.0fms", ms)
                            } else {
                                serverLatencies[server] = "\(avgMs)ms"
                            }
                        }
                    }
                } else if result.exitCode != 0 {
                    serverLatencies[server] = "timeout"
                }
            } catch {
                serverLatencies[server] = "timeout"
            }
        }

        isTestingServers = false
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
