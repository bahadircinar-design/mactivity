import Foundation

enum Format {
    /// Memory sizes use binary units, like Activity Monitor.
    static func bytes(_ value: UInt64) -> String {
        scaled(Double(value), base: 1024, units: ["B", "KB", "MB", "GB", "TB"])
    }

    /// Network amounts use decimal units, like Finder and most ISPs.
    static func data(_ value: UInt64) -> String {
        scaled(Double(value), base: 1000, units: ["B", "KB", "MB", "GB", "TB"])
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        scaled(max(0, bytesPerSecond), base: 1000, units: ["B/s", "KB/s", "MB/s", "GB/s"])
    }

    static func bitrate(_ bitsPerSecond: Double) -> String {
        let mbps = bitsPerSecond / 1_000_000
        if mbps >= 1000 { return String(format: "%.2f Gbps", mbps / 1000) }
        if mbps >= 100 { return String(format: "%.0f Mbps", mbps) }
        return String(format: "%.1f Mbps", mbps)
    }

    static func percent(_ value: Double) -> String {
        String(format: value >= 10 ? "%.0f%%" : "%.1f%%", value)
    }

    static func ms(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: value < 10 ? "%.1f ms" : "%.0f ms", value)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func scaled(_ value: Double, base: Double, units: [String]) -> String {
        var amount = value
        var index = 0
        while amount >= base && index < units.count - 1 {
            amount /= base
            index += 1
        }
        let number: String
        if index == 0 {
            number = String(format: "%.0f", amount)
        } else if amount >= 100 {
            number = String(format: "%.0f", amount)
        } else if amount >= 10 {
            number = String(format: "%.1f", amount)
        } else {
            number = String(format: "%.2f", amount)
        }
        return number + " " + units[index]
    }
}
