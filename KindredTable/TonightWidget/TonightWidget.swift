import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TonightEntry: TimelineEntry {
    let date: Date
    let recipeName: String?
    let mealType: String?
    let totalMinutes: String?
    let summary: String?

    static var placeholder: TonightEntry {
        TonightEntry(date: Date(), recipeName: "Lemon Herb Chicken",
                     mealType: "Dinner", totalMinutes: "30",
                     summary: "Bright and fresh, just right for tonight.")
    }

    static var empty: TonightEntry {
        TonightEntry(date: Date(), recipeName: nil, mealType: nil,
                     totalMinutes: nil, summary: nil)
    }
}

// MARK: - Timeline Provider

struct TonightProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.kindred.KindredTable")

    func placeholder(in context: Context) -> TonightEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TonightEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TonightEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh at midnight when the new day's plan may differ
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func currentEntry() -> TonightEntry {
        guard let snapshot = defaults?.dictionary(forKey: "kt.tonight.plan") as? [String: String] else {
            return .empty
        }
        return TonightEntry(date: Date(),
                            recipeName: snapshot["title"],
                            mealType: snapshot["mealType"],
                            totalMinutes: snapshot["totalMinutes"],
                            summary: snapshot["summary"])
    }
}

// MARK: - Widget View

struct TonightWidgetView: View {
    var entry: TonightEntry
    @Environment(\.widgetFamily) private var family

    // Brand warm orange
    private let accent = Color(red: 1.0, green: 0.55, blue: 0.30)

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
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func plannedView(name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Text("Tonight")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
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
                .foregroundStyle(accent)
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

struct TonightWidget: Widget {
    let kind = "TonightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TonightProvider()) { entry in
            TonightWidgetView(entry: entry)
        }
        .configurationDisplayName("Tonight's Dinner")
        .description("See what's planned, or tap to find a recipe.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    TonightWidget()
} timeline: {
    TonightEntry.placeholder
    TonightEntry.empty
}
