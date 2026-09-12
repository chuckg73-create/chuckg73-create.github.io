import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TonightPlanEntry: TimelineEntry {
    let date: Date
    let recipeName: String?
    let mealType: String?
    let totalMinutes: String?
    let summary: String?

    static var placeholder: TonightPlanEntry {
        TonightPlanEntry(date: Date(), recipeName: "Lemon Herb Chicken",
                         mealType: "Dinner", totalMinutes: "30", summary: "Bright and fresh, just right for tonight.")
    }

    static var empty: TonightPlanEntry {
        TonightPlanEntry(date: Date(), recipeName: nil, mealType: nil, totalMinutes: nil, summary: nil)
    }
}

// MARK: - Timeline Provider

struct TonightPlanProvider: TimelineProvider {

    private let defaults = UserDefaults(suiteName: "group.com.kindred.KindredTable")

    func placeholder(in context: Context) -> TonightPlanEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TonightPlanEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TonightPlanEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh at midnight (when tomorrow's plan may differ) and again at 5 pm (dinner nudge hour)
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func currentEntry() -> TonightPlanEntry {
        guard let snapshot = defaults?.dictionary(forKey: "kt.tonight.plan") as? [String: String] else {
            return .empty
        }
        return TonightPlanEntry(
            date: Date(),
            recipeName: snapshot["title"],
            mealType: snapshot["mealType"],
            totalMinutes: snapshot["totalMinutes"],
            summary: snapshot["summary"]
        )
    }
}

// MARK: - Widget Views

struct TonightPlanWidgetView: View {
    var entry: TonightPlanEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let name = entry.recipeName {
                plannedView(name: name)
            } else {
                emptyView
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.10, blue: 0.08),
                         Color(red: 0.18, green: 0.14, blue: 0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private func plannedView(name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.30))
                Text("Tonight")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.30))
                Spacer()
                if let mins = entry.totalMinutes {
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.caption2)
                        Text("\(mins)m").font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer(minLength: 2)
            Text(name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(family == .systemSmall ? 2 : 1)
            if family != .systemSmall, let summary = entry.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Text(entry.mealType ?? "")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(family == .systemSmall ? 14 : 16)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.30))
            Spacer()
            Text("What's for dinner?")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text("Tap to find tonight's recipe.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(family == .systemSmall ? 14 : 16)
    }
}

// MARK: - Widget Definition

struct KindredTableWidget: Widget {
    let kind = "KindredTableWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TonightPlanProvider()) { entry in
            TonightPlanWidgetView(entry: entry)
        }
        .configurationDisplayName("Tonight's Dinner")
        .description("See what's planned for dinner, or tap to find a recipe.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    KindredTableWidget()
} timeline: {
    TonightPlanEntry.placeholder
    TonightPlanEntry.empty
}
