import Foundation
import os

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
    private let logger = Logger(subsystem: "io.tunk.make-my-mac-fast-again", category: "dns-flush")
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
        DNSPreset(name: "Quad9", server: "9.9.9.9"),
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
            _ = try await privilegedExecutor.run(.flushDNS)
            flushSucceeded = true
            lastFlushDate = Date()
            logger.info("DNS cache flushed successfully")
            statusMessage = "DNS cache flushed successfully."
        } catch {
            flushSucceeded = false
            logger.warning("DNS flush failed: \(error.localizedDescription)")
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

        let validServerPattern = /^[a-zA-Z0-9.:]+$/
        let validServers = serversToTest.filter { $0.wholeMatch(of: validServerPattern) != nil }

        let results = await withTaskGroup(
            of: (server: String, latency: String).self,
            returning: [(server: String, latency: String)].self
        ) { [shell] group in
            for server in validServers {
                group.addTask {
                    let executable = server.contains(":") ? "/sbin/ping6" : "/sbin/ping"
                    let args = server.contains(":") ? ["-c", "1", server] : ["-c", "1", "-t", "2", server]
                    do {
                        let result = try await shell.run(executablePath: executable, arguments: args)
                        if let rtLine = result.output.components(separatedBy: "\n").last(where: { $0.contains("round-trip") }) {
                            let parts = rtLine.components(separatedBy: "=")
                            if parts.count >= 2 {
                                let values = parts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: "/")
                                if values.count >= 2 {
                                    let avgMs = values[1].trimmingCharacters(in: .whitespaces)
                                    if let ms = Double(avgMs) {
                                        return (server: server, latency: String(format: "%.0fms", ms))
                                    }
                                    return (server: server, latency: "\(avgMs)ms")
                                }
                            }
                        }
                        if result.exitCode != 0 {
                            return (server: server, latency: "timeout")
                        }
                        return (server: server, latency: "timeout")
                    } catch {
                        return (server: server, latency: "timeout")
                    }
                }
            }
            var collected: [(server: String, latency: String)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        for result in results {
            serverLatencies[result.server] = result.latency
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
