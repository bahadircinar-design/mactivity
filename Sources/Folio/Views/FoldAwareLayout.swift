import SwiftUI

/// Manual fold split for custom chrome when ArrangementView isn't the right fit.
/// Prefer `ArrangementView` for primary/secondary note layouts.
struct FoldAwareSplit<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        GeometryReader { proxy in
            let divisions = proxy.reservedRegions(kind: .division)
            if let division = divisions.first {
                let frame = division.frame
                if frame.height > frame.width {
                    HStack(spacing: 0) {
                        leading()
                            .frame(width: max(frame.minX, 0))
                        Color.clear
                            .frame(width: frame.width)
                        trailing()
                            .frame(width: max(proxy.size.width - frame.maxX, 0))
                    }
                } else {
                    VStack(spacing: 0) {
                        leading()
                            .frame(height: max(frame.minY, 0))
                        Color.clear
                            .frame(height: frame.height)
                        trailing()
                            .frame(height: max(proxy.size.height - frame.maxY, 0))
                    }
                }
            } else {
                // Flat display: side-by-side when wide, stacked when tall.
                if proxy.size.width > proxy.size.height {
                    HStack(spacing: 0) {
                        leading()
                            .frame(width: min(proxy.size.width * 0.36, 340))
                        Rectangle()
                            .fill(FolioTheme.sealRed.opacity(0.22))
                            .frame(width: 1)
                        trailing()
                    }
                } else {
                    VStack(spacing: 0) {
                        leading()
                            .frame(height: proxy.size.height * 0.38)
                        Rectangle()
                            .fill(FolioTheme.sealRed.opacity(0.22))
                            .frame(height: 1)
                        trailing()
                    }
                }
            }
        }
    }
}

struct DuoPoseBadge: View {
    var body: some View {
        GeometryReader { proxy in
            let folded = !proxy.reservedRegions(kind: .division).isEmpty
            let label = folded ? "Folded split" : (proxy.size.width > 700 ? "Inner canvas" : "Outer capture")
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .foregroundStyle(FolioTheme.inkSoft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(12)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
