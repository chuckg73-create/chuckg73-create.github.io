import SwiftUI

/// A personal timeline of every dish the cook has rated — the "cooking diary"
/// that makes KindredTable feel like it knows you.
struct RecipeJournalView: View {
    @Environment(TasteFeedbackStore.self) private var feedback

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// Ratings grouped by calendar month, newest month first.
    private var grouped: [(month: String, monthDate: Date, ratings: [RecipeRating])] {
        let dict = Dictionary(grouping: feedback.ratings) {
            Self.monthFormatter.string(from: $0.date)
        }
        return dict
            .map { key, value -> (String, Date, [RecipeRating]) in
                let anchor = value.first?.date ?? Date.distantPast
                let sorted = value.sorted { $0.date > $1.date }
                return (key, anchor, sorted)
            }
            .sorted { $0.1 > $1.1 }
            .map { (month: $0.0, monthDate: $0.1, ratings: $0.2) }
    }

    private var lovedCount: Int { feedback.ratings.filter { $0.verdict == .loved }.count }
    private var madeCount: Int { feedback.ratings.count }

    var body: some View {
        ZStack {
            KindredBackground()
            if feedback.ratings.isEmpty {
                EmptyState(
                    systemImage: "clock.arrow.circlepath",
                    title: "Nothing cooked yet",
                    message: "Rate the recipes you make and they'll show up here — your personal cooking diary."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        statsRow
                        ForEach(grouped, id: \.month) { group in
                            monthSection(group)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Cooking History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statPill(value: "\(madeCount)", label: "Dishes made",
                     icon: "fork.knife", color: KindredTheme.accent)
            statPill(value: "\(lovedCount)", label: "Loved",
                     icon: "heart.fill", color: KindredTheme.coral)
        }
    }

    private func statPill(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3.weight(.bold)).foregroundStyle(KindredTheme.text)
                Text(label).font(.caption2).foregroundStyle(KindredTheme.subtext)
            }
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    private func monthSection(_ group: (month: String, monthDate: Date, ratings: [RecipeRating])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.month.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(KindredTheme.faint)
                .tracking(0.8)
            ForEach(group.ratings) { rating in
                journalCard(rating)
            }
        }
    }

    private func journalCard(_ rating: RecipeRating) -> some View {
        HStack(spacing: 14) {
            Image(systemName: rating.verdict.systemImage)
                .font(.title3)
                .foregroundStyle(verdictColor(rating.verdict))
                .frame(width: 40, height: 40)
                .background(verdictColor(rating.verdict).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(rating.recipeTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KindredTheme.text)
                HStack(spacing: 6) {
                    Text(rating.verdict.title)
                        .font(.caption2)
                        .foregroundStyle(verdictColor(rating.verdict))
                    Text("·").font(.caption2).foregroundStyle(KindredTheme.faint)
                    Text(rating.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2).foregroundStyle(KindredTheme.faint)
                }
                if !rating.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(rating.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .foregroundStyle(KindredTheme.subtext)
                                .background(KindredTheme.subtext.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(verdictColor(rating.verdict).opacity(0.18), lineWidth: 1))
    }

    private func verdictColor(_ v: RecipeVerdict) -> Color {
        switch v {
        case .loved:    return KindredTheme.coral
        case .liked:    return KindredTheme.mint
        case .disliked: return KindredTheme.faint
        }
    }
}

#Preview {
    NavigationStack {
        RecipeJournalView()
            .environment(TasteFeedbackStore(seed: [
                RecipeRating(recipeTitle: "Lemon Herb Chicken", verdict: .loved,
                             tags: ["Mediterranean", "One-pan"], mealType: "dinner",
                             date: Date()),
                RecipeRating(recipeTitle: "Spicy Thai Basil Stir-fry", verdict: .liked,
                             tags: ["Thai", "Quick"], mealType: "dinner",
                             date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!),
                RecipeRating(recipeTitle: "Mushroom Risotto", verdict: .disliked,
                             tags: ["Italian"], mealType: "dinner",
                             date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!),
            ]))
    }
    .preferredColorScheme(.dark)
}
