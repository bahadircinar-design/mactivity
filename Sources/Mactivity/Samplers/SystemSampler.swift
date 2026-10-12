import Foundation
import Darwin

struct CPUTicks: Sendable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32
}

struct CPUUsage: Sendable {
    var user: Double
    var system: Double
    var total: Double { min(100, user + system) }
    var idle: Double { max(0, 100 - total) }
}

enum MemoryPressure: String, Sendable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"
}

struct MemoryStats: Sendable {
    var total: UInt64
    var app: UInt64
    var wired: UInt64
    var compressed: UInt64
    var cached: UInt64
    var free: UInt64
    var swapUsed: UInt64
    var swapTotal: UInt64
    var pressure: MemoryPressure

    /// Same definition as Activity Monitor's "Memory Used".
    var used: UInt64 { app + wired + compressed }
    var usedFraction: Double { total > 0 ? min(1, Double(used) / Double(total)) : 0 }
}

enum SystemSampler {
    private static let host = mach_host_self()

    // MARK: CPU

    static func cpuTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(host, HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(user: info.cpu_ticks.0,
                        system: info.cpu_ticks.1,
                        idle: info.cpu_ticks.2,
                        nice: info.cpu_ticks.3)
    }

    static func usage(from old: CPUTicks, to new: CPUTicks) -> CPUUsage {
        let user = Double(new.user &- old.user) + Double(new.nice &- old.nice)
        let system = Double(new.system &- old.system)
        let idle = Double(new.idle &- old.idle)
        let total = user + system + idle
        guard total > 0 else { return CPUUsage(user: 0, system: 0) }
        return CPUUsage(user: user / total * 100, system: system / total * 100)
    }

    // MARK: Memory

    static func memory() -> MemoryStats? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(host, HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        _ = host_page_size(host, &pageSize)
        let page = UInt64(pageSize > 0 ? pageSize : 4096)

        let anonymousPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        let app = (anonymousPages > purgeable ? anonymousPages - purgeable : 0) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let cached = (UInt64(stats.external_page_count) + purgeable) * page
        let free = UInt64(stats.free_count) * page

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let hasSwap = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0

        return MemoryStats(
            total: ProcessInfo.processInfo.physicalMemory,
            app: app,
            wired: wired,
            compressed: compressed,
            cached: cached,
            free: free,
            swapUsed: hasSwap ? swap.xsu_used : 0,
            swapTotal: hasSwap ? swap.xsu_total : 0,
            pressure: pressure()
        )
    }

    private static func pressure() -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else {
            return .unknown
        }
        switch level {
        case 1: return .normal
        case 2: return .warning
        case 4: return .critical
        default: return .unknown
        }
    }

    // MARK: System info

    static func bootDate() -> Date? {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0, boot.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(boot.tv_sec) + TimeInterval(boot.tv_usec) / 1_000_000)
    }

    static func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        return getloadavg(&loads, 3) == 3 ? loads : []
    }

    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let text = buffer.withUnsafeBufferPointer { pointer -> String in
            guard let base = pointer.baseAddress else { return "" }
            return String(cString: base)
        }
        return text.isEmpty ? nil : text
    }
}
