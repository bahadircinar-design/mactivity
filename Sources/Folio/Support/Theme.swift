import SwiftUI

enum FolioTheme {
    /// Cool slate paper — not warm cream.
    static let paper = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let paperDeep = Color(red: 0.86, green: 0.88, blue: 0.91)
    static let ink = Color(red: 0.10, green: 0.14, blue: 0.20)
    static let inkSoft = Color(red: 0.28, green: 0.33, blue: 0.40)
    static let moss = Color(red: 0.18, green: 0.38, blue: 0.30)
    static let dusk = Color(red: 0.30, green: 0.26, blue: 0.48)
    static let copper = Color(red: 0.62, green: 0.36, blue: 0.22)
    static let sea = Color(red: 0.16, green: 0.42, blue: 0.52)
    static let hairline = Color.black.opacity(0.08)

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

struct PaperBackground: View {
    var body: some View {
        ZStack {
            FolioTheme.paper
            GeometryReader { proxy in
                Canvas { context, size in
                    var hasher = Hasher()
                    let cols = max(Int(size.width / 18), 1)
                    let rows = max(Int(size.height / 18), 1)
                    for row in 0..<rows {
                        for col in 0..<cols {
                            hasher.combine(row)
                            hasher.combine(col)
                            let hash = hasher.finalize()
                            hasher = Hasher()
                            if hash % 7 != 0 { continue }
                            let x = CGFloat(col) * 18 + CGFloat(abs(hash) % 11)
                            let y = CGFloat(row) * 18 + CGFloat(abs(hash / 11) % 11)
                            let rect = CGRect(x: x, y: y, width: 1.1, height: 1.1)
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(.black.opacity(0.035))
                            )
                        }
                    }
                }
                .allowsHitTesting(false)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.55),
                        Color.clear,
                        FolioTheme.ink.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

struct FolioBrandMark: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            FoldGlyph()
                .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
            Text("Folio")
                .font(.system(compact ? .title3 : .largeTitle, design: .serif).weight(.semibold))
                .foregroundStyle(FolioTheme.ink)
                .tracking(-0.4)
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

            context.fill(left, with: .color(FolioTheme.moss))
            context.fill(right, with: .color(FolioTheme.ink))
        }
        .accessibilityHidden(true)
    }
}
