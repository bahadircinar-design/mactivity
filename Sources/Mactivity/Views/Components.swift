import SwiftUI
import AppKit
import Charts

enum Palette {
    static let cpu = Color.blue
    static let system = Color.red
    static let memory = Color.purple
    static let download = Color.teal
    static let upload = Color.orange
}

// MARK: - Cards

extension View {
    func cardBackground(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
            )
    }
}

struct Card<Content: View>: View {
    let title: String
    let symbol: String?
    let trailing: String?
    let fillHeight: Bool
    let content: Content

    init(_ title: String, symbol: String? = nil, trailing: String? = nil, fillHeight: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.trailing = trailing
        self.fillHeight = fillHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol).foregroundStyle(.secondary)
                }
                Text(title).font(.headline)
                Spacer()
                if let trailing {
                    Text(trailing).font(.caption).foregroundStyle(.secondary)
                }
            }
            content
        }
        .frame(maxHeight: fillHeight ? CGFloat.infinity : nil, alignment: .top)
        .cardBackground()
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    let symbol: String
    let tint: Color
    var fraction: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let fraction {
                ProgressView(value: min(max(fraction, 0), 1))
                    .progressViewStyle(.linear)
                    .tint(tint)
            }
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .cardBackground(padding: 14)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(monospaced ? Font.body.monospaced() : Font.body)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

struct LegendValue: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit().fontWeight(.medium)
        }
        .font(.callout)
    }
}

struct UsageBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(tint)
                    .frame(width: max(2, geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Process icons

final class IconCache {
    static let shared = IconCache()
    private var cache: [String: NSImage] = [:]

    func icon(forPath path: String) -> NSImage {
        if let image = cache[path] { return image }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache[path] = image
        return image
    }
}

struct ProcessIcon: View {
    let bundlePath: String?
    let kind: ProcessKind
    var size: CGFloat = 16

    var body: some View {
        if let bundlePath {
            Image(nsImage: IconCache.shared.icon(forPath: bundlePath))
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: kind == .system ? "gearshape.fill" : "terminal.fill")
                .font(.system(size: size * 0.7))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
}

struct RankRow: View {
    let bundlePath: String?
    let kind: ProcessKind
    let name: String
    let value: String
    let fraction: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            ProcessIcon(bundlePath: bundlePath, kind: kind, size: 20)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name).lineLimit(1)
                    Spacer()
                    Text(value).monospacedDigit().foregroundStyle(.secondary)
                }
                UsageBar(fraction: fraction, tint: tint)
            }
        }
    }
}

// MARK: - Charts

enum ChartFormat {
    case percent
    case milliseconds

    func label(_ value: Double) -> String {
        switch self {
        case .percent: return "\(Int(value.rounded()))%"
        case .milliseconds: return "\(Int(value.rounded())) ms"
        }
    }
}

struct HistoryChart: View {
    let samples: [ValueSample]
    let tint: Color
    let maxValue: Double
    let format: ChartFormat

    var body: some View {
        Chart(samples) { sample in
            AreaMark(x: .value("Time", sample.date), y: .value("Value", sample.value))
                .foregroundStyle(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.03)],
                                                startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Time", sample.date), y: .value("Value", sample.value))
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.monotone)
        }
        .chartYScale(domain: 0...maxValue)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(format.label(number))
                    }
                }
            }
        }
    }
}

struct ThroughputChart: View {
    let samples: [RateSample]

    private var ceiling: Double {
        let peak = samples.map { max($0.down, $0.up) }.max() ?? 0
        return max(peak * 1.15, 20_000)
    }

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(x: .value("Time", sample.date),
                         y: .value("Rate", sample.down),
                         series: .value("Direction", "Download"))
                    .foregroundStyle(by: .value("Direction", "Download"))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Time", sample.date),
                         y: .value("Rate", sample.up),
                         series: .value("Direction", "Upload"))
                    .foregroundStyle(by: .value("Direction", "Upload"))
                    .interpolationMethod(.monotone)
            }
        }
        .chartForegroundStyleScale(["Download": Palette.download, "Upload": Palette.upload])
        .chartLegend(.hidden)
        .chartYScale(domain: 0...ceiling)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(Format.rate(number))
                    }
                }
            }
        }
    }
}

// MARK: - Memory breakdown

struct MemorySegment: Identifiable {
    let name: String
    let bytes: UInt64
    let color: Color
    var id: String { name }
}

struct MemoryBreakdown: View {
    let memory: MemoryStats

    private var segments: [MemorySegment] {
        [
            MemorySegment(name: "App", bytes: memory.app, color: Palette.memory),
            MemorySegment(name: "Wired", bytes: memory.wired, color: .pink),
            MemorySegment(name: "Compressed", bytes: memory.compressed, color: .orange),
            MemorySegment(name: "Cached files", bytes: memory.cached, color: .teal.opacity(0.6))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: max(0, geometry.size.width * share(segment.bytes)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 14)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                ForEach(segments) { segment in
                    LegendValue(color: segment.color, label: segment.name, value: Format.bytes(segment.bytes))
                }
            }
        }
    }

    private func share(_ bytes: UInt64) -> Double {
        memory.total > 0 ? Double(bytes) / Double(memory.total) : 0
    }
}
