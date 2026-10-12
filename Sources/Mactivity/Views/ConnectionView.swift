import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var connection: ConnectionStore
    @EnvironmentObject var stats: StatsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusHero
                latencyTiles
                latencyCard
                HStack(alignment: .top, spacing: 12) {
                    detailsCard
                    WiFiCard(wifi: connection.wifi, location: connection.location)
                }
                speedTestCard
            }
            .padding(20)
        }
        .navigationTitle("Connection")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await connection.runChecks()
                        await connection.fetchPublicIP()
                    }
                } label: {
                    Label("Check Now", systemImage: "arrow.clockwise")
                }
                .help("Run the connection checks again")
            }
        }
    }

    // MARK: Status

    private var statusHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(connection.status.color.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: connection.interfaceSymbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(connection.status.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: connection.status.symbol)
                        .foregroundStyle(connection.status.color)
                    Text(connection.status.headline)
                        .font(.title2.weight(.semibold))
                }
                Text(connectionSummary)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let checked = connection.lastChecked {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last checked").font(.caption).foregroundStyle(.secondary)
                    Text(checked, style: .time).font(.callout).monospacedDigit()
                }
            }
        }
        .cardBackground(padding: 18)
    }

    private var connectionSummary: String {
        var parts = ["Using \(connection.interfaceType)"]
        if let name = connection.interfaceName { parts.append(name) }
        if let ssid = connection.wifi?.ssid, connection.interfaceType == "Wi-Fi" { parts.append("“\(ssid)”") }
        if connection.isExpensive { parts.append("metered connection") }
        if connection.isConstrained { parts.append("Low Data Mode on") }
        return parts.joined(separator: " · ")
    }

    // MARK: Latency

    private var latencyTiles: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            StatTile(title: "Internet latency", value: Format.ms(connection.internetPing?.averageMs),
                     detail: latencyVerdict(connection.internetPing?.averageMs) + " · ping to 1.1.1.1",
                     symbol: "globe", tint: latencyColor(connection.internetPing?.averageMs))
            StatTile(title: "Router latency", value: Format.ms(connection.routerPing?.averageMs),
                     detail: connection.globals.router.map { "ping to \($0)" } ?? "No router found",
                     symbol: "wifi.router", tint: latencyColor(connection.routerPing?.averageMs))
            StatTile(title: "Web response", value: Format.ms(connection.webResponseMs),
                     detail: "HTTPS request to apple.com",
                     symbol: "safari", tint: latencyColor(connection.webResponseMs.map { $0 / 3 }))
            StatTile(title: "Packet loss", value: connection.internetPing.map { Format.percent($0.lossPercent) } ?? "—",
                     detail: "of the last 3 pings",
                     symbol: "waveform.path.ecg",
                     tint: (connection.internetPing?.lossPercent ?? 0) > 0 ? .orange : .green)
        }
    }

    private var latencyCard: some View {
        let peak = connection.latencyHistory.map(\.value).max() ?? 0
        return Card("Latency over time", symbol: "waveform.path.ecg", trailing: "Checked every 10 seconds") {
            if connection.latencyHistory.count < 2 {
                Text("Collecting measurements…")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                HistoryChart(samples: connection.latencyHistory, tint: .green,
                             maxValue: max(50, peak * 1.25), format: .milliseconds)
                    .frame(height: 140)
            }
        }
    }

    private func latencyVerdict(_ ms: Double?) -> String {
        guard let ms else { return "No reply" }
        switch ms {
        case ..<30: return "Excellent"
        case ..<80: return "Good"
        case ..<150: return "Fair"
        default: return "Slow"
        }
    }

    private func latencyColor(_ ms: Double?) -> Color {
        guard let ms else { return .gray }
        switch ms {
        case ..<80: return .green
        case ..<150: return .orange
        default: return .red
        }
    }

    // MARK: Details

    private var detailsCard: some View {
        Card("Network details", symbol: "network") {
            VStack(spacing: 9) {
                InfoRow(label: "Local IP", value: localIP ?? "—", monospaced: true)
                InfoRow(label: "Public IP", value: connection.publicIP ?? "—", monospaced: true)
                InfoRow(label: "Router", value: connection.globals.router ?? "—", monospaced: true)
                InfoRow(label: "DNS servers",
                        value: connection.globals.dnsServers.isEmpty
                            ? "—"
                            : connection.globals.dnsServers.prefix(3).joined(separator: "\n"),
                        monospaced: true)
                Divider()
                InfoRow(label: "IP versions", value: ipVersions)
                InfoRow(label: "Low Data Mode", value: connection.isConstrained ? "On" : "Off")
                InfoRow(label: "Metered connection", value: connection.isExpensive ? "Yes (e.g. iPhone hotspot)" : "No")
            }
        }
    }

    private var localIP: String? {
        let primary = connection.globals.primaryInterface ?? connection.interfaceName
        if let primary, let match = stats.interfaces.first(where: { $0.name == primary }) {
            return match.ipv4.first ?? match.ipv6.first
        }
        return stats.interfaces.first?.ipv4.first
    }

    private var ipVersions: String {
        switch (connection.supportsIPv4, connection.supportsIPv6) {
        case (true, true): return "IPv4 + IPv6"
        case (true, false): return "IPv4 only"
        case (false, true): return "IPv6 only"
        default: return "—"
        }
    }

    // MARK: Speed test

    private var speedTestCard: some View {
        Card("Speed test", symbol: "speedometer", trailing: "Uses Cloudflare's public test servers") {
            HStack(alignment: .center, spacing: 28) {
                SpeedFigure(title: "Download", symbol: "arrow.down.circle.fill", tint: Palette.download,
                            bitsPerSecond: speedResults.down)
                SpeedFigure(title: "Upload", symbol: "arrow.up.circle.fill", tint: Palette.upload,
                            bitsPerSecond: speedResults.up)
                Spacer()
                switch connection.speedTest {
                case .running(let phase):
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(phase).foregroundStyle(.secondary)
                    }
                case .finished(_, _, let date):
                    VStack(alignment: .trailing, spacing: 6) {
                        Button("Run Again") { connection.runSpeedTest() }
                        Text("Tested at \(date.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .idle:
                    Button("Run Speed Test") { connection.runSpeedTest() }
                        .buttonStyle(.borderedProminent)
                        .disabled(connection.status == .offline)
                }
            }
        }
    }

    private var speedResults: (down: Double?, up: Double?) {
        if case .finished(let down, let up, _) = connection.speedTest {
            return (down, up)
        }
        return (nil, nil)
    }
}

private struct SpeedFigure: View {
    let title: String
    let symbol: String
    let tint: Color
    let bitsPerSecond: Double?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Text(bitsPerSecond.map { Format.bitrate($0) } ?? "—")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}

private struct WiFiCard: View {
    let wifi: WiFiDetails?
    @ObservedObject var location: LocationAccess

    var body: some View {
        Card("Wi-Fi", symbol: "wifi") {
            if let wifi, wifi.isConnected {
                VStack(spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Network").foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        networkName(wifi)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("Signal").foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Image(systemName: "wifi", variableValue: wifi.signalFraction)
                            .foregroundStyle(signalColor(wifi))
                        Text("\(wifi.rssi) dBm · \(wifi.quality)")
                    }
                    InfoRow(label: "Noise", value: "\(wifi.noise) dBm (SNR \(wifi.signalToNoise) dB)")
                    InfoRow(label: "Link speed", value: String(format: "%.0f Mbps", wifi.transmitRate))
                    if let channel = wifi.channel {
                        InfoRow(label: "Channel", value: "\(channel)" + (wifi.band.map { " · \($0)" } ?? ""))
                    }
                    if let standard = wifi.standard {
                        InfoRow(label: "Standard", value: standard)
                    }
                    if let name = wifi.interfaceName {
                        InfoRow(label: "Interface", value: name)
                    }
                }
            } else {
                Text(message)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var message: String {
        guard let wifi else { return "This Mac has no Wi-Fi hardware, or it isn't available." }
        return wifi.isPoweredOn ? "Wi-Fi is on but not connected to a network." : "Wi-Fi is turned off."
    }

    private func signalColor(_ wifi: WiFiDetails) -> Color {
        switch wifi.rssi {
        case -65...0: return .green
        case -75 ..< -65: return .orange
        default: return .red
        }
    }

    @ViewBuilder
    private func networkName(_ wifi: WiFiDetails) -> some View {
        if let ssid = wifi.ssid {
            Text(ssid).fontWeight(.medium).textSelection(.enabled)
        } else if location.status == .notDetermined {
            Button("Show network name") { location.request() }
                .controlSize(.small)
                .help("macOS only shares the Wi-Fi name with apps that have Location access.")
        } else if location.isDenied {
            Button("Allow in Settings…") { location.openSettings() }
                .controlSize(.small)
                .help("macOS only shares the Wi-Fi name with apps that have Location access.")
        } else {
            Text("Hidden by macOS").foregroundStyle(.secondary)
        }
    }
}
