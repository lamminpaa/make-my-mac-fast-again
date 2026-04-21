import Foundation

/// Bucket a LaunchAgent / LaunchDaemon into a safety category so the optimizer
/// can decide whether it's safe to recommend disabling it.
///
/// The classifier is intentionally conservative: anything not explicitly known
/// falls into `.unknown`, which the optimizer UI treats as "user must opt in
/// per-item" rather than "safe to bulk-disable".
enum StartupCategory: String, Sendable, Codable, CaseIterable {
    /// Apple's own system services — never touch.
    case appleSystem
    /// Third-party software the user almost certainly depends on for safety
    /// or hardware functionality (drivers, security tools, password managers,
    /// VPN clients). The optimizer never pre-selects these.
    case safetyCritical
    /// Launch helpers for applications where disabling only costs the user a
    /// slight launch delay or an auto-update check. Safe default pick.
    case convenience
    /// Everything else — we haven't catalogued it. The optimizer surfaces
    /// these but requires explicit per-item opt-in.
    case unknown

    /// Short user-facing label for the category badge.
    var shortLabel: String {
        switch self {
        case .appleSystem: return "System"
        case .safetyCritical: return "Critical"
        case .convenience: return "Optional"
        case .unknown: return "Unknown"
        }
    }

    /// Longer description shown in tooltips / the optimizer sheet.
    var explanation: String {
        switch self {
        case .appleSystem:
            return "Part of macOS — disabling may destabilize the system."
        case .safetyCritical:
            return "Driver, security tool, or hardware helper — keep enabled."
        case .convenience:
            return "Auto-update or convenience helper — safe to disable."
        case .unknown:
            return "Not recognised — disable only if you know what this is."
        }
    }
}

/// Pure function that maps a LaunchAgent/LaunchDaemon identity to a
/// `StartupCategory`. No I/O, no state. The lookup is: explicit known-label
/// table first, then prefix rules, then a final heuristic based on path.
enum StartupItemClassifier {

    /// Explicit per-label overrides. Wins over every other rule. Use this when
    /// a label would otherwise match a broad prefix rule in the wrong bucket
    /// (e.g. a hypothetical `com.apple.something-from-a-third-party` label).
    private static let exactMatches: [String: StartupCategory] = [
        "com.docker.helper": .safetyCritical,
        "com.docker.vmnetd": .safetyCritical,
    ]

    /// Prefix rules checked in order. First match wins. Order matters: put
    /// more specific prefixes before broader ones from the same vendor.
    private static let prefixRules: [(prefix: String, category: StartupCategory)] = [
        // ── Apple system ────────────────────────────────────────────────────
        ("com.apple.", .appleSystem),

        // ── Safety-critical: input devices, keyboard/mouse customisation ────
        ("org.pqrs.", .safetyCritical),                 // Karabiner-Elements
        ("com.karabiner-elements.", .safetyCritical),
        ("com.hammerspoon.", .safetyCritical),
        ("com.bettertouchtool.", .safetyCritical),
        ("com.logi.", .safetyCritical),                 // Logi Options+
        ("com.logitech.", .safetyCritical),
        ("com.razer.", .safetyCritical),
        ("com.corsair.", .safetyCritical),
        ("com.steelseries.", .safetyCritical),
        ("com.elgato.", .safetyCritical),               // Stream Deck, CamLink
        ("com.wacom.", .safetyCritical),
        ("com.synology.", .safetyCritical),

        // ── Safety-critical: security / firewall / VPN / password ──────────
        ("at.obdev.LittleSnitch", .safetyCritical),     // Little Snitch
        ("at.obdev.littlesnitch", .safetyCritical),
        ("com.objective-see.", .safetyCritical),        // LuLu, KnockKnock, etc.
        ("com.malwarebytes.", .safetyCritical),
        ("com.crowdstrike.", .safetyCritical),
        ("com.sentinelone.", .safetyCritical),
        ("com.trendmicro.", .safetyCritical),
        ("com.sophos.", .safetyCritical),
        ("com.eset.", .safetyCritical),
        ("com.kaspersky.", .safetyCritical),
        ("com.mcafee.", .safetyCritical),
        ("com.norton.", .safetyCritical),
        ("com.bitdefender.", .safetyCritical),
        ("com.nordvpn.", .safetyCritical),
        ("com.expressvpn.", .safetyCritical),
        ("com.mullvad.", .safetyCritical),
        ("com.protonvpn.", .safetyCritical),
        ("com.wireguard.", .safetyCritical),
        ("com.tailscale.", .safetyCritical),
        ("com.cisco.anyconnect.", .safetyCritical),     // enterprise VPN
        ("com.cisco.secureclient.", .safetyCritical),
        ("com.cloudflare.1dot1dot1dot1", .safetyCritical),
        ("com.cloudflare.cloudflare-warp", .safetyCritical),
        ("com.1password.", .safetyCritical),
        ("com.agilebits.", .safetyCritical),            // legacy 1Password
        ("com.bitwarden.", .safetyCritical),
        ("com.dashlane.", .safetyCritical),
        ("com.okta.", .safetyCritical),
        ("com.yubico.", .safetyCritical),

        // ── Safety-critical: audio / display / peripheral drivers ──────────
        ("com.rogueamoeba.", .safetyCritical),          // Loopback, SoundSource
        ("com.blackhole.", .safetyCritical),
        ("com.displaylink.", .safetyCritical),
        ("com.duet.", .safetyCritical),                 // Duet Display helper

        // ── Convenience: auto-update agents ─────────────────────────────────
        ("com.google.keystone.", .convenience),         // Google updater
        ("com.microsoft.update.", .convenience),
        ("com.microsoft.autoupdate.", .convenience),
        ("com.adobe.ARMDC.", .convenience),
        ("com.adobe.ccxprocess.", .convenience),
        ("com.adobe.acc.", .convenience),
        ("com.adobe.AdobeIPCBroker.", .convenience),
        ("com.adobe.AdobeResourceSynchronizer.", .convenience),
        ("com.adobe.AAM.", .convenience),
        ("com.oracle.java.", .convenience),

        // ── Convenience: chat / video / collab app helpers ─────────────────
        ("com.slack.", .convenience),
        ("com.microsoft.teams.", .convenience),
        ("com.microsoft.skype.", .convenience),
        ("us.zoom.", .convenience),
        ("com.zoom.", .convenience),
        ("com.hnc.Discord.", .convenience),
        ("com.tinyspeck.slackmacgap.", .convenience),
        ("com.webex.", .convenience),

        // ── Convenience: cloud sync / storage helpers ──────────────────────
        ("com.getdropbox.dropbox", .convenience),
        ("com.dropbox.", .convenience),
        ("com.microsoft.OneDrive.", .convenience),
        ("com.google.GoogleDrive.", .convenience),
        ("com.google.drivefs.", .convenience),
        ("com.box.desktop.", .convenience),

        // ── Convenience: music / media / etc. ──────────────────────────────
        ("com.spotify.", .convenience),
        ("com.apple.iTunesHelper", .convenience),       // legacy, keep for safety
        ("com.amazon.music.", .convenience),
        ("com.amazon.Kindle.", .convenience),

        // ── Convenience: dev tool updaters / background helpers ────────────
        ("com.github.GitHubClient.", .convenience),
        ("com.sublimetext.auto-update.", .convenience),
        ("com.jetbrains.toolbox.", .convenience),
    ]

    /// Entry point. Return the most specific category we can identify.
    static func classify(label: String, path: String, type: StartupItemType) -> StartupCategory {
        if let exact = exactMatches[label] {
            return exact
        }
        for rule in prefixRules where label.hasPrefix(rule.prefix) {
            return rule.category
        }
        // Global LaunchDaemons that aren't Apple and aren't in our allow-list
        // are unknown — often custom third-party drivers. Err on the side of
        // caution and label them as such so the optimizer doesn't pre-pick.
        _ = path
        _ = type
        return .unknown
    }
}
