import Foundation
import Combine
import SystemConfiguration

struct ValueSample: Identifiable, Sendable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct RateSample: Identifiable, Sendable {
    let date: Date
    let down: Double
    let up: Double
    var id: Date { date }
}

struct InterfaceRow: Identifiable, Sendable {
    let name: String
    let displayName: String
    let ipv4: [String]
    let ipv6: [String]
    let downRate: Double
    let upRate: Double
    var id: String { name }
}

/// CPU, memory and network-interface figures, sampled once a second.
@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var cpu = CPUUsage(user: 0, system: 0)
    @Published private(set) var cpuHistory: [ValueSample] = []
    @Published private(set) var memory: MemoryStats?
    @Published private(set) var memoryHistory: [ValueSample] = []
    @Published private(set) var loadAverage: [Double] = []

    @Published private(set) var downRate: Double = 0
    @Published private(set) var upRate: Double = 0
    @Published private(set) var networkHistory: [RateSample] = []
    @Published private(set) var sessionReceived: UInt64 = 0
    @Published private(set) var sessionSent: UInt64 = 0
    @Published private(set) var interfaces: [InterfaceRow] = []

    let computerName: String
    let chipName: String?
    let osVersion: String
    let coreCount = ProcessInfo.processInfo.activeProcessorCount
    let bootDate = SystemSampler.bootDate()

    /// Two minutes of one-second samples.
    let historyLength = 120

    private var lastTicks: CPUTicks?
    private var lastCounters: [String: InterfaceCounter] = [:]
    private var lastSampleDate: Date?
    private var displayNames: [String: String] = [:]
    private var tickCount = 0
    private var loop: Task<Void, Never>?

    init() {
        computerName = (SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? "This Mac"
        chipName = SystemSampler.sysctlString("machdep.cpu.brand_string")
        let version = ProcessInfo.processInfo.operatingSystemVersion
        osVersion = version.patchVersion > 0
            ? "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            : "macOS \(version.majorVersion).\(version.minorVersion)"
        displayNames = InterfaceSampler.displayNames()

        sample()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.sample()
            }
        }
    }

    private func sample() {
        let now = Date()
        tickCount += 1

        if let ticks = SystemSampler.cpuTicks() {
            if let previous = lastTicks {
                cpu = SystemSampler.usage(from: previous, to: ticks)
                append(ValueSample(date: now, value: cpu.total), to: &cpuHistory)
            }
            lastTicks = ticks
        }

        if let reading = SystemSampler.memory() {
            memory = reading
            append(ValueSample(date: now, value: reading.usedFraction * 100), to: &memoryHistory)
        }

        loadAverage = SystemSampler.loadAverage()

        if tickCount % 30 == 0 {
            displayNames = InterfaceSampler.displayNames()
        }
        sampleNetwork(at: now)
    }

    private func sampleNetwork(at now: Date) {
        let snapshot = InterfaceSampler.snapshot()
        let elapsed = lastSampleDate.map { now.timeIntervalSince($0) } ?? 0

        var rows: [InterfaceRow] = []
        var totalDown = 0.0
        var totalUp = 0.0
        var receivedDelta: UInt64 = 0
        var sentDelta: UInt64 = 0

        for (name, counter) in snapshot.counters {
            var down = 0.0
            var up = 0.0
            if elapsed > 0, let previous = lastCounters[name] {
                let received = Double(counter.received &- previous.received)
                let sent = Double(counter.sent &- previous.sent)
                // A jump above 1.5 GB/s means the counter was reset (interface restarted), not real traffic.
                let ceiling = elapsed * 1_500_000_000
                if received < ceiling && sent < ceiling {
                    down = received / elapsed
                    up = sent / elapsed
                    // Physical interfaces only; VPN tunnels ride on top of them and would double-count.
                    if name.hasPrefix("en") {
                        totalDown += down
                        totalUp += up
                        receivedDelta += UInt64(received)
                        sentDelta += UInt64(sent)
                    }
                }
            }

            let v4 = snapshot.ipv4[name] ?? []
            let v6 = snapshot.ipv6[name] ?? []
            if name != "lo0" && (!v4.isEmpty || (name.hasPrefix("en") && !v6.isEmpty)) {
                rows.append(InterfaceRow(
                    name: name,
                    displayName: displayNames[name] ?? InterfaceSampler.fallbackName(for: name),
                    ipv4: v4,
                    ipv6: v6,
                    downRate: down,
                    upRate: up
                ))
            }
        }

        lastCounters = snapshot.counters
        lastSampleDate = now
        interfaces = rows.sorted { lhs, rhs in
            (lhs.name.hasPrefix("en") ? 0 : 1, lhs.name) < (rhs.name.hasPrefix("en") ? 0 : 1, rhs.name)
        }

        guard elapsed > 0 else { return }
        downRate = totalDown
        upRate = totalUp
        sessionReceived += receivedDelta
        sessionSent += sentDelta
        append(RateSample(date: now, down: totalDown, up: totalUp), to: &networkHistory)
    }

    private func append<T>(_ value: T, to history: inout [T]) {
        history.append(value)
        if history.count > historyLength {
            history.removeFirst(history.count - historyLength)
        }
    }
}
