import SwiftUI

enum FolioTheme {
    /// Xuan / rice-paper wash — warm fiber sheet for Chinese practice paper.
    static let paper = Color(red: 0.965, green: 0.945, blue: 0.900)
    static let paperDeep = Color(red: 0.925, green: 0.895, blue: 0.835)
    static let ink = Color(red: 0.12, green: 0.10, blue: 0.11)
    static let inkSoft = Color(red: 0.38, green: 0.32, blue: 0.30)
    /// Classic practice-grid vermilion (朱砂).
    static let sealRed = Color(red: 0.78, green: 0.22, blue: 0.20)
    static let gridRed = Color(red: 0.82, green: 0.30, blue: 0.26).opacity(0.38)
    static let moss = Color(red: 0.22, green: 0.40, blue: 0.30)
    static let dusk = Color(red: 0.34, green: 0.28, blue: 0.46)
    static let copper = Color(red: 0.58, green: 0.34, blue: 0.22)
    static let sea = Color(red: 0.20, green: 0.40, blue: 0.48)
    static let hairline = Color.black.opacity(0.07)

    static func accentColor(_ accent: NoteAccent) -> Color {
        switch accent {
        case .ink: ink
        case .moss: moss
        case .dusk: dusk
        case .copper: copper
        case .sea: sea
        }
    }
}

enum FolioFont {
    /// Flowing Latin handwriting for note bodies.
    static let hand = "Caveat"
    /// Brush calligraphy for the brand and display titles.
    static let brush = "Ma Shan Zheng"

    static func handwriting(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(hand, size: size, relativeTo: textStyle)
    }

    static func brushDisplay(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .custom(brush, size: size, relativeTo: textStyle)
    }
}

/// Chinese 米字格 (mi-zi-ge) practice paper with fibrous rice-paper texture.
struct PaperBackground: View {
    var cellSize: CGFloat = 56

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                FolioTheme.paper

                // Fiber wash
                Canvas { context, size in
                    drawFibers(context: &context, size: size)
                    drawFlecks(context: &context, size: size)
                }
                .allowsHitTesting(false)

                // Soft edge burn / aged wash
                RadialGradient(
                    colors: [
                        Color.clear,
                        FolioTheme.copper.opacity(0.05),
                        Color.black.opacity(0.04)
                    ],
                    center: .center,
                    startRadius: min(proxy.size.width, proxy.size.height) * 0.25,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.75
                )

                // 米字格 grid
                Canvas { context, size in
                    drawMiZiGe(context: &context, size: size, cell: cellSize)
                }
                .allowsHitTesting(false)

                // Top light on the sheet
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.35),
                        Color.clear,
                        FolioTheme.ink.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }

    private func drawFibers(context: inout GraphicsContext, size: CGSize) {
        var hasher = Hasher()
        let count = Int(size.width * size.height / 900)
        for i in 0..<count {
            hasher.combine(i)
            let h = hasher.finalize()
            hasher = Hasher()
            let x = CGFloat(abs(h) % max(Int(size.width), 1))
            let y = CGFloat(abs(h / 31) % max(Int(size.height), 1))
            let length = CGFloat(8 + abs(h) % 22)
            let angle = Double(abs(h) % 360) * .pi / 180
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(
                x: x + CGFloat(cos(angle)) * length,
                y: y + CGFloat(sin(angle)) * length
            ))
            context.stroke(
                path,
                with: .color(FolioTheme.ink.opacity(0.025 + Double(abs(h) % 5) * 0.004)),
                lineWidth: 0.6
            )
        }
    }

    private func drawFlecks(context: inout GraphicsContext, size: CGSize) {
        var hasher = Hasher()
        let cols = max(Int(size.width / 14), 1)
        let rows = max(Int(size.height / 14), 1)
        for row in 0..<rows {
            for col in 0..<cols {
                hasher.combine(row * 997 + col)
                let hash = hasher.finalize()
                hasher = Hasher()
                if hash % 9 != 0 { continue }
                let x = CGFloat(col) * 14 + CGFloat(abs(hash) % 10)
                let y = CGFloat(row) * 14 + CGFloat(abs(hash / 13) % 10)
                let r = CGFloat(0.6 + Double(abs(hash) % 3) * 0.4)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r * 0.7)),
                    with: .color(FolioTheme.ink.opacity(0.04))
                )
            }
        }
    }

    private func drawMiZiGe(context: inout GraphicsContext, size: CGSize, cell: CGFloat) {
        let cols = Int(ceil(size.width / cell)) + 1
        let rows = Int(ceil(size.height / cell)) + 1
        let outer = FolioTheme.gridRed
        let inner = FolioTheme.sealRed.opacity(0.18)

        for row in 0..<rows {
            for col in 0..<cols {
                let rect = CGRect(
                    x: CGFloat(col) * cell,
                    y: CGFloat(row) * cell,
                    width: cell,
                    height: cell
                )
                context.stroke(Path(rect), with: .color(outer), lineWidth: 0.8)

                // 米 diagonals + cross
                var mid = Path()
                mid.move(to: CGPoint(x: rect.minX, y: rect.midY))
                mid.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                mid.move(to: CGPoint(x: rect.midX, y: rect.minY))
                mid.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                mid.move(to: CGPoint(x: rect.minX, y: rect.minY))
                mid.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                mid.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                mid.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                context.stroke(mid, with: .color(inner), style: StrokeStyle(lineWidth: 0.55, dash: [3, 4]))
            }
        }
    }
}

struct FolioBrandMark: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            FoldGlyph()
                .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
            VStack(alignment: .leading, spacing: 0) {
                Text("Folio")
                    .font(FolioFont.brushDisplay(compact ? 28 : 40, relativeTo: compact ? .title3 : .largeTitle))
                    .foregroundStyle(FolioTheme.ink)
                Text("宣纸 · 手札")
                    .font(FolioFont.handwriting(compact ? 13 : 15, relativeTo: .caption))
                    .foregroundStyle(FolioTheme.sealRed.opacity(0.85))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Folio")
    }
}

struct FoldGlyph: View {
    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 2
            let midX = size.width / 2
            var left = Path()
            left.move(to: CGPoint(x: inset, y: inset))
            left.addLine(to: CGPoint(x: midX - 1, y: inset + 2))
            left.addLine(to: CGPoint(x: midX - 1, y: size.height - inset))
            left.addLine(to: CGPoint(x: inset + 2, y: size.height - inset - 3))
            left.closeSubpath()

            var right = Path()
            right.move(to: CGPoint(x: midX + 1, y: inset + 2))
            right.addLine(to: CGPoint(x: size.width - inset, y: inset))
            right.addLine(to: CGPoint(x: size.width - inset - 2, y: size.height - inset - 3))
            right.addLine(to: CGPoint(x: midX + 1, y: size.height - inset))
            right.closeSubpath()

            context.fill(left, with: .color(FolioTheme.sealRed))
            context.fill(right, with: .color(FolioTheme.ink))
        }
        .accessibilityHidden(true)
    }
}
