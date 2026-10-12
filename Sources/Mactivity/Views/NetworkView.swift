import SwiftUI

/// Sort order for the per-app table, kept outside @State so Command Line Tools builds work.
@MainActor
final class TrafficTableState: ObservableObject {
    @Published var sortOrder: [KeyPathComparator<AppTrafficRow>] = [KeyPathComparator(\AppTrafficRow.downRate, order: .reverse)]
}

struct NetworkView: View {
    @EnvironmentObject var stats: StatsStore
    @EnvironmentObject var processes: ProcessStore
    @StateObject private var tableState = TrafficTableState()

    private let fourColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: fourColumns, spacing: 12) {
                StatTile(title: "Download", value: Format.rate(stats.downRate),
                         detail: "right now", symbol: "arrow.down.circle.fill", tint: Palette.download)
                StatTile(title: "Upload", value: Format.rate(stats.upRate),
                         detail: "right now", symbol: "arrow.up.circle.fill", tint: Palette.upload)
                StatTile(title: "Received", value: Format.data(stats.sessionReceived),
                         detail: "since Mactivity opened", symbol: "tray.and.arrow.down.fill", tint: Palette.download)
                StatTile(title: "Sent", value: Format.data(stats.sessionSent),
                         detail: "since Mactivity opened", symbol: "tray.and.arrow.up.fill", tint: Palette.upload)
            }

            HStack(alignment: .top, spacing: 12) {
                Card("Throughput", symbol: "chart.xyaxis.line", trailing: "Last 2 minutes") {
                    ThroughputChart(samples: stats.networkHistory)
                        .frame(height: 150)
                    HStack(spacing: 16) {
                        LegendValue(color: Palette.download, label: "Download", value: Format.rate(stats.downRate))
                        LegendValue(color: Palette.upload, label: "Upload", value: Format.rate(stats.upRate))
                    }
                }
                Card("Interfaces", symbol: "network") {
                    interfaceList
                }
                .frame(width: 330)
            }

            Card("Apps using the network", symbol: "app.connected.to.app.below.fill",
                 trailing: "Updated every few seconds", fillHeight: true) {
                trafficTable
            }
            .frame(maxHeight: .infinity)
        }
        .padding(20)
        .navigationTitle("Network")
    }

    // MARK: Interfaces

    private var interfaceList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if stats.interfaces.isEmpty {
                    Text("No active network interfaces.").foregroundStyle(.secondary)
                }
                ForEach(stats.interfaces) { interface in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(interface.displayName).fontWeight(.medium)
                            Text(interface.name).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("↓ \(Format.rate(interface.downRate))")
                                .foregroundStyle(Palette.download)
                            Text("↑ \(Format.rate(interface.upRate))")
                                .foregroundStyle(Palette.upload)
                        }
                        .font(.callout)
                        .monospacedDigit()
                        ForEach(interface.ipv4 + interface.ipv6.prefix(1), id: \.self) { address in
                            Text(address)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 176)
    }

    // MARK: Per-app traffic

    @ViewBuilder
    private var trafficTable: some View {
        if !processes.trafficAvailable {
            Text("macOS didn't return per-app network data, so only the totals above are available.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Table(processes.traffic.sorted(using: tableState.sortOrder), sortOrder: $tableState.sortOrder) {
                TableColumn("Process", value: \AppTrafficRow.sortName) { (row: AppTrafficRow) in
                    HStack(spacing: 8) {
                        ProcessIcon(bundlePath: row.bundlePath, kind: row.kind)
                        Text(row.name).lineLimit(1)
                    }
                }
                .width(min: 200, ideal: 280)

                TableColumn("Download", value: \AppTrafficRow.downRate) { (row: AppTrafficRow) in
                    RateCell(rate: row.downRate, tint: Palette.download)
                }
                .width(min: 90, ideal: 110)

                TableColumn("Upload", value: \AppTrafficRow.upRate) { (row: AppTrafficRow) in
                    RateCell(rate: row.upRate, tint: Palette.upload)
                }
                .width(min: 90, ideal: 110)

                TableColumn("Received", value: \AppTrafficRow.received) { (row: AppTrafficRow) in
                    Text(Format.data(row.received)).monospacedDigit().foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 100)

                TableColumn("Sent", value: \AppTrafficRow.sent) { (row: AppTrafficRow) in
                    Text(Format.data(row.sent)).monospacedDigit().foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 100)

                TableColumn("PID", value: \AppTrafficRow.pid) { (row: AppTrafficRow) in
                    Text(String(row.pid)).monospacedDigit().foregroundStyle(.secondary)
                }
                .width(min: 50, ideal: 64)
            }
            .frame(minHeight: 200)
        }
    }
}

private struct RateCell: View {
    let rate: Double
    let tint: Color

    var body: some View {
        Text(rate >= 1 ? Format.rate(rate) : "—")
            .monospacedDigit()
            .foregroundStyle(rate >= 1_000 ? tint : Color.secondary)
    }
}
