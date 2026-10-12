import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case overview, processes, network, connection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .processes: return "Processes"
        case .network: return "Network"
        case .connection: return "Connection"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .processes: return "list.bullet.rectangle"
        case .network: return "arrow.up.arrow.down.circle"
        case .connection: return "globe"
        }
    }
}

/// Which screen is showing. An ObservableObject rather than @State so the app also builds
/// with Apple's Command Line Tools (which lack the SwiftUI macro plugin).
@MainActor
final class NavigationModel: ObservableObject {
    @Published var selection: SidebarItem? = .overview
}

struct ContentView: View {
    @StateObject private var navigation = NavigationModel()

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $navigation.selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            switch navigation.selection ?? .overview {
            case .overview:
                OverviewView(selection: $navigation.selection)
            case .processes:
                ProcessesView()
            case .network:
                NetworkView()
            case .connection:
                ConnectionView()
            }
        }
    }
}

/// The sidebar observes the live stores on its own, so the detail views only
/// re-render when their own data changes.
private struct Sidebar: View {
    @EnvironmentObject var stats: StatsStore
    @EnvironmentObject var processes: ProcessStore
    @EnvironmentObject var connection: ConnectionStore
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section("Monitor") {
                ForEach(SidebarItem.allCases) { item in
                    SidebarRow(item: item, detail: detail(for: item), dot: dot(for: item))
                        .tag(item)
                }
            }
        }
    }

    private func detail(for item: SidebarItem) -> String {
        switch item {
        case .overview: return Format.percent(stats.cpu.total) + " CPU"
        case .processes: return processes.processes.isEmpty ? "" : "\(processes.processes.count)"
        case .network: return "↓ " + Format.rate(stats.downRate)
        case .connection: return connection.status.title
        }
    }

    private func dot(for item: SidebarItem) -> Color? {
        item == .connection ? connection.status.color : nil
    }
}

private struct SidebarRow: View {
    let item: SidebarItem
    let detail: String
    let dot: Color?

    var body: some View {
        HStack(spacing: 6) {
            Label(item.title, systemImage: item.symbol)
            Spacer(minLength: 4)
            if let dot {
                Circle().fill(dot).frame(width: 7, height: 7)
            }
            Text(detail)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
