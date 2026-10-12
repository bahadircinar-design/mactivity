import Foundation
import SystemConfiguration
import CoreWLAN

struct PingResult: Sendable, Equatable {
    let averageMs: Double?
    let lossPercent: Double
}

struct NetworkGlobals: Sendable, Equatable {
    var router: String?
    var primaryInterface: String?
    var dnsServers: [String] = []
}

struct WiFiDetails: Sendable, Equatable {
    var interfaceName: String?
    var isPoweredOn: Bool
    var ssid: String?
    var rssi: Int
    var noise: Int
    var transmitRate: Double
    var channel: Int?
    var band: String?
    var standard: String?

    var isConnected: Bool { isPoweredOn && rssi != 0 }
    var signalToNoise: Int { rssi - noise }

    /// 0…1, mapping −90 dBm (unusable) to −40 dBm (excellent).
    var signalFraction: Double { min(1, max(0, Double(rssi + 90) / 50)) }

    var quality: String {
        switch rssi {
        case -55...0: return "Excellent"
        case -65 ..< -55: return "Good"
        case -75 ..< -65: return "Fair"
        default: return "Weak"
        }
    }
}

enum ConnectionProbe {
    // MARK: Latency

    static func ping(_ host: String) -> PingResult {
        let output = Shell.run("/sbin/ping", ["-n", "-c", "3", "-t", "5", host], timeout: 8) ?? ""
        return parsePing(output)
    }

    /// Reads the summary lines of macOS ping:
    ///   "3 packets transmitted, 3 packets received, 0.0% packet loss"
    ///   "round-trip min/avg/max/stddev = 12.1/14.0/16.2/1.7 ms"
    static func parsePing(_ output: String) -> PingResult {
        var average: Double?
        if let statsRange = output.range(of: "min/avg/max"),
           let equals = output[statsRange.upperBound...].firstIndex(of: "=") {
            let numbers = output[output.index(after: equals)...]
                .trimmingCharacters(in: .whitespaces)
                .split(separator: "/")
            if numbers.count >= 2 { average = Double(numbers[1]) }
        }

        var loss = average == nil ? 100.0 : 0.0
        if let lossRange = output.range(of: "% packet loss") {
            let prefix = output[..<lossRange.lowerBound]
            if let space = prefix.lastIndex(of: " "),
               let value = Double(prefix[prefix.index(after: space)...]) {
                loss = value
            }
        }
        return PingResult(averageMs: average, lossPercent: loss)
    }

    // MARK: Router & DNS

    static func globals() -> NetworkGlobals {
        guard let store = SCDynamicStoreCreate(nil, "Mactivity" as CFString, nil, nil) else {
            return NetworkGlobals()
        }
        let ipv4 = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any]
        let dns = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any]
        return NetworkGlobals(
            router: ipv4?["Router"] as? String,
            primaryInterface: ipv4?["PrimaryInterface"] as? String,
            dnsServers: dns?["ServerAddresses"] as? [String] ?? []
        )
    }

    // MARK: Wi-Fi

    static func wifi() -> WiFiDetails? {
        guard let interface = CWWiFiClient.shared().interface() else { return nil }
        guard interface.powerOn() else {
            return WiFiDetails(interfaceName: interface.interfaceName, isPoweredOn: false, ssid: nil,
                               rssi: 0, noise: 0, transmitRate: 0, channel: nil, band: nil, standard: nil)
        }
        let channel = interface.wlanChannel()
        return WiFiDetails(
            interfaceName: interface.interfaceName,
            isPoweredOn: true,
            ssid: interface.ssid(),
            rssi: interface.rssiValue(),
            noise: interface.noiseMeasurement(),
            transmitRate: interface.transmitRate(),
            channel: channel?.channelNumber,
            band: channel.map { bandName($0.channelBand.rawValue) },
            standard: standardName(interface.activePHYMode().rawValue)
        )
    }

    private static func bandName(_ raw: Int) -> String {
        switch raw {
        case 1: return "2.4 GHz"
        case 2: return "5 GHz"
        case 3: return "6 GHz"
        default: return "Unknown band"
        }
    }

    private static func standardName(_ raw: Int) -> String? {
        switch raw {
        case 1: return "802.11a"
        case 2: return "802.11b"
        case 3: return "802.11g"
        case 4: return "Wi-Fi 4 (802.11n)"
        case 5: return "Wi-Fi 5 (802.11ac)"
        case 6: return "Wi-Fi 6 (802.11ax)"
        case 7: return "Wi-Fi 7 (802.11be)"
        default: return nil
        }
    }
}
