import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes (shared shape between main app and widget)

struct CookingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stepNumber: Int
        var totalSteps: Int
        /// First ~60 chars of current step text — keeps the payload small.
        var stepText: String
        /// End time of the most urgent running timer, if any.
        var timerEnd: Date?
        var recipeName: String
    }
    var recipeName: String
}

// MARK: - Live Activity Widget

struct CookingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookingActivityAttributes.self) { context in
            // Lock Screen / StandBy banner
            lockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.12, green: 0.10, blue: 0.08))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Cooking", systemImage: "fork.knife")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                        Text(context.state.recipeName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Step \(context.state.stepNumber)/\(context.state.totalSteps)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                        if let end = context.state.timerEnd {
                            Text(timerInterval: Date()...end, countsDown: true)
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.stepText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    stepProgressBar(current: context.state.stepNumber,
                                    total: context.state.totalSteps)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: "fork.knife").foregroundStyle(accent)
            } compactTrailing: {
                if let end = context.state.timerEnd {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(maxWidth: 44)
                } else {
                    Text("\(context.state.stepNumber)/\(context.state.totalSteps)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                }
            } minimal: {
                Text("\(context.state.stepNumber)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }

    private let accent = Color(red: 1.0, green: 0.55, blue: 0.30)

    private func lockScreenView(context: ActivityViewContext<CookingActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife.circle.fill").foregroundStyle(accent)
                    Text(context.state.recipeName)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text("Step \(context.state.stepNumber) of \(context.state.totalSteps)")
                        .font(.caption.weight(.semibold)).foregroundStyle(accent)
                }
                Text(context.state.stepText)
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                stepProgressBar(current: context.state.stepNumber, total: context.state.totalSteps)
                    .padding(.top, 2)
            }
            if let end = context.state.timerEnd {
                VStack(spacing: 2) {
                    Image(systemName: "timer").font(.caption2).foregroundStyle(accent)
                    Text(timerInterval: Date()...end, countsDown: true)
                        .font(.headline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 60)
                }
            }
        }
        .padding(16)
    }

    private func stepProgressBar(current: Int, total: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12)).frame(height: 4)
                Capsule()
                    .fill(accent)
                    .frame(width: max(8, geo.size.width * CGFloat(current) / CGFloat(max(1, total))),
                           height: 4)
            }
        }
        .frame(height: 4)
    }
}
