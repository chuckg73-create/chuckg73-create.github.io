import SwiftUI

/// Shimmering placeholder that matches RecipeCard's dimensions exactly.
/// Shown during recipe generation so the layout is never a blank spinner.
struct RecipeCardSkeleton: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Hero image band
            shimmer(height: 148, radius: 0)

            VStack(alignment: .leading, spacing: 12) {
                // Chip + title + badge
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        shimmer(width: 76, height: 24, radius: 12)
                        shimmer(height: 22, radius: 6)
                        shimmer(width: 150, height: 22, radius: 6)
                    }
                    Spacer()
                    shimmer(width: 44, height: 56, radius: 12)
                }

                // Summary lines
                shimmer(height: 13, radius: 4)
                shimmer(width: 210, height: 13, radius: 4)

                // Meta row
                HStack(spacing: 14) {
                    shimmer(width: 62, height: 12, radius: 4)
                    shimmer(width: 62, height: 12, radius: 4)
                }

                // Ingredient chips
                HStack(spacing: 6) {
                    shimmer(width: 72, height: 26, radius: 13)
                    shimmer(width: 62, height: 26, radius: 13)
                    shimmer(width: 82, height: 26, radius: 13)
                }
            }
            .padding(16)
        }
        .background(KindredTheme.card,
                    in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous)
                .stroke(KindredTheme.hairline, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    @ViewBuilder
    private func shimmer(width: CGFloat? = nil, height: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        KindredTheme.faint.opacity(0.25),
                        KindredTheme.faint.opacity(0.55),
                        KindredTheme.faint.opacity(0.25),
                    ],
                    startPoint: UnitPoint(x: phase - 0.6, y: 0),
                    endPoint:   UnitPoint(x: phase + 0.6, y: 0)
                )
            )
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

#Preview {
    ZStack {
        KindredBackground()
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in RecipeCardSkeleton() }
            }
            .padding(20)
        }
    }
    .preferredColorScheme(.dark)
}
