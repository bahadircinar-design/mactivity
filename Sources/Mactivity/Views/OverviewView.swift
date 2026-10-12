import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var stats: StatsStore
    @EnvironmentObject var processes: ProcessStore
    @EnvironmentObject var connection: ConnectionStore
    @Binding var selection: SidebarItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                tiles
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        cpuCard
                        networkCard
                    }
                    GridRow {
                        memoryCard
                        topMemoryCard
                    }
                    GridRow {
                        topCPUCard
                        topNetworkCard
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Overview")
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stats.computerName)
                .font(.system(size: 28, weight: .bold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let chip = stats.chipName { parts.append(chip) }
        parts.append(stats.osVersion)
        parts.append("\(stats.coreCount) cores")
        if let memory = stats.memory { parts.append(Format.bytes(memory.total) + " memory") }
        if let boot = stats.bootDate { parts.append("up " + Format.duration(Date().timeIntervalSince(boot))) }
        return parts.joined(separator: "  ·  ")
    }

    // MARK: Tiles

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
            Button { selection = .processes } label: {
                StatTile(title: "CPU", value: Format.percent(stats.cpu.total),
                         detail: "User \(Format.percent(stats.cpu.user)) · System \(Format.percent(stats.cpu.system))",
                         symbol: "cpu", tint: Palette.cpu, fraction: stats.cpu.total / 100)
            }
            .buttonStyle(.plain)

            Button { selection = .processes } label: {
                StatTile(title: "Memory",
                         value: stats.memory.map { Format.bytes($0.used) } ?? "—",
                         detail: stats.memory.map { "of \(Format.bytes($0.total)) · Pressure \($0.pressure.rawValue)" },
                         symbol: "memorychip", tint: Palette.memory,
                         fraction: stats.memory?.usedFraction)
            }
            .buttonStyle(.plain)

            Button { selection = .network } label: {
                StatTile(title: "Network", value: "↓ " + Format.rate(stats.downRate),
                         detail: "↑ " + Format.rate(stats.upRate),
                         symbol: "arrow.up.arrow.down.circle.fill", tint: Palette.download)
            }
            .buttonStyle(.plain)

            Button { selection = .connection } label: {
                StatTile(title: "Internet", value: connection.status.title,
                         detail: "\(connection.interfaceType) · \(Format.ms(connection.internetPing?.averageMs ?? connection.webResponseMs))",
                         symbol: connection.status.symbol, tint: connection.status.color)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Charts

    private var cpuCard: some View {
        Card("CPU", symbol: "cpu", trailing: loadAverageText, fillHeight: true) {
            HistoryChart(samples: stats.cpuHistory, tint: Palette.cpu, maxValue: 100, format: .percent)
                .frame(height: 130)
            HStack(spacing: 16) {
                LegendValue(color: Palette.cpu, label: "User", value: Format.percent(stats.cpu.user))
                LegendValue(color: Palette.system, label: "System", value: Format.percent(stats.cpu.system))
                LegendValue(color: .gray, label: "Idle", value: Format.percent(stats.cpu.idle))
            }
        }
    }

    private var loadAverageText: String? {
        guard stats.loadAverage.count == 3 else { return nil }
        return String(format: "Load %.2f  %.2f  %.2f", stats.loadAverage[0], stats.loadAverage[1], stats.loadAverage[2])
    }

    private var networkCard: some View {
        Card("Network", symbol: "arrow.up.arrow.down", trailing: "Last 2 minutes", fillHeight: true) {
            ThroughputChart(samples: stats.networkHistory)
                .frame(height: 130)
            HStack(spacing: 16) {
                LegendValue(color: Palette.download, label: "Download", value: Format.rate(stats.downRate))
                LegendValue(color: Palette.upload, label: "Upload", value: Format.rate(stats.upRate))
            }
        }
    }

    private var memoryCard: some View {
        Card("Memory", symbol: "memorychip", trailing: stats.memory.map { "Pressure: \($0.pressure.rawValue)" }, fillHeight: true) {
            if let memory = stats.memory {
                MemoryBreakdown(memory: memory)
                Divider()
                InfoRow(label: "Used", value: "\(Format.bytes(memory.used)) of \(Format.bytes(memory.total))")
                InfoRow(label: "Swap used", value: memory.swapTotal > 0
                        ? "\(Format.bytes(memory.swapUsed)) of \(Format.bytes(memory.swapTotal))"
                        : "None")
            } else {
                Text("Reading memory…").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Top lists

    private var topMemoryCard: some View {
        let top = Array(processes.processes.sorted { $0.memory > $1.memory }.prefix(6))
        let peak = Double(max(top.first?.memory ?? 1, 1))
        return Card("Top memory", symbol: "memorychip", trailing: "See all", fillHeight: true) {
            VStack(spacing: 10) {
                ForEach(top) { row in
                    RankRow(bundlePath: row.bundlePath, kind: row.kind, name: row.name,
                            value: Format.bytes(row.memory), fraction: Double(row.memory) / peak, tint: Palette.memory)
                }
            }
        }
        .onTapGesture { selection = .processes }
    }

    private var topCPUCard: some View {
        let top = Array(processes.processes.sorted { $0.cpu > $1.cpu }.prefix(6))
        let peak = max(top.first?.cpu ?? 1, 1)
        return Card("Top CPU", symbol: "cpu", trailing: "See all", fillHeight: true) {
            VStack(spacing: 10) {
                ForEach(top) { row in
                    RankRow(bundlePath: row.bundlePath, kind: row.kind, name: row.name,
                            value: String(format: "%.1f%%", row.cpu), fraction: row.cpu / peak, tint: Palette.cpu)
                }
            }
        }
        .onTapGesture { selection = .processes }
    }

    private var topNetworkCard: some View {
        let top = Array(processes.traffic.prefix(6))
        let peak = max(top.map { $0.downRate + $0.upRate }.max() ?? 1, 1)
        return Card("Top network", symbol: "arrow.up.arrow.down", trailing: "See all", fillHeight: true) {
            if top.isEmpty {
                Text(processes.trafficAvailable ? "Gathering per-app traffic…" : "Per-app traffic isn't available on this Mac.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(top) { row in
                        RankRow(bundlePath: row.bundlePath, kind: row.kind, name: row.name,
                                value: "↓ \(Format.rate(row.downRate))  ↑ \(Format.rate(row.upRate))",
                                fraction: (row.downRate + row.upRate) / peak, tint: Palette.download)
                    }
                }
            }
        }
        .onTapGesture { selection = .network }
    }
}
