import Foundation
import Darwin
import SystemConfiguration

struct InterfaceCounter: Sendable {
    /// Bytes received / sent. macOS keeps these as 32-bit counters, so they wrap
    /// every 4 GB — rates are computed with wrapping subtraction.
    let received: UInt32
    let sent: UInt32
}

struct InterfaceSnapshot: Sendable {
    var counters: [String: InterfaceCounter] = [:]
    var ipv4: [String: [String]] = [:]
    var ipv6: [String: [String]] = [:]
}

enum InterfaceSampler {
    static func snapshot() -> InterfaceSnapshot {
        var snapshot = InterfaceSnapshot()
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return snapshot }
        defer { freeifaddrs(head) }

        var cursor = head
        while let entry = cursor {
            cursor = entry.pointee.ifa_next
            guard let address = entry.pointee.ifa_addr else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            let family = Int32(address.pointee.sa_family)

            if family == AF_LINK {
                if let data = entry.pointee.ifa_data {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    snapshot.counters[name] = InterfaceCounter(received: stats.ifi_ibytes, sent: stats.ifi_obytes)
                }
            } else if family == AF_INET {
                if let text = numericHost(address) {
                    snapshot.ipv4[name, default: []].append(text)
                }
            } else if family == AF_INET6 {
                // Skip link-local (fe80::) addresses; they're only meaningful on the local link.
                if let text = numericHost(address), !text.lowercased().hasPrefix("fe80") {
                    snapshot.ipv6[name, default: []].append(text)
                }
            }
        }
        return snapshot
    }

    /// Friendly names like "Wi-Fi" or "Thunderbolt Bridge", keyed by BSD name ("en0").
    static func displayNames() -> [String: String] {
        var names: [String: String] = [:]
        let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []
        for interface in interfaces {
            guard let bsdName = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? else { continue }
            names[bsdName] = displayName
        }
        return names
    }

    static func fallbackName(for bsdName: String) -> String {
        if bsdName.hasPrefix("utun") || bsdName.hasPrefix("ipsec") { return "VPN" }
        if bsdName.hasPrefix("bridge") { return "Bridge" }
        if bsdName.hasPrefix("en") { return "Ethernet" }
        return bsdName
    }

    private static func numericHost(_ address: UnsafeMutablePointer<sockaddr>) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(address, socklen_t(address.pointee.sa_len),
                                 &buffer, socklen_t(buffer.count),
                                 nil, 0, NI_NUMERICHOST)
        guard result == 0 else { return nil }
        let text = buffer.withUnsafeBufferPointer { pointer -> String in
            guard let base = pointer.baseAddress else { return "" }
            return String(cString: base)
        }
        // Drop IPv6 scope suffixes such as "%en0".
        return text.split(separator: "%").first.map(String.init)
    }
}
