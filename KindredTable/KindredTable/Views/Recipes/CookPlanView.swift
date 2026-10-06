import SwiftUI

/// "Cook by a time" — pick when you want to eat and KindredTable back-times
/// each task, then schedules reminders so every component finishes together.
struct CookPlanView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss

    @State private var serveTime: Date = CookPlanView.defaultServeTime(for: nil)
    @State private var didSchedule = false
    @State private var scheduledCount = 0
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        intro
                        timePicker
                        schedulePreview
                        actionButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Cook by a time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { if serveDefaulted == false { serveTime = Self.defaultServeTime(for: recipe); serveDefaulted = true } }
            .onChange(of: serveTime) { didSchedule = false }
            .alert("Notifications are off", isPresented: $showPermissionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow notifications in Settings to get cooking reminders. You can still see the schedule here.")
            }
        }
    }

    @State private var serveDefaulted = false
    private var tasks: [CookPlanner.ScheduledTask] { CookPlanner.plan(for: recipe, serveTime: serveTime) }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("When should it be ready?")
                .font(.title3).fontWeight(.bold).foregroundStyle(KindredTheme.text)
            Text("Pick your serve time and we'll back-time every step, then remind you when to start each one — so it all comes out together.")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
        }
    }

    private var timePicker: some View {
        HStack {
            Label("Serve at", systemImage: "fork.knife").foregroundStyle(KindredTheme.text)
            Spacer()
            DatePicker("", selection: $serveTime, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .tint(KindredTheme.accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var schedulePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(label: "Your timeline")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    timelineRow(task: task, index: index, total: tasks.count)
                }
            }
        }
    }

    private func timelineRow(task: CookPlanner.ScheduledTask, index: Int, total: Int) -> some View {
        let isLast = index == total - 1
        let isNow = !task.isPast && (index == 0 || tasks[index - 1].isPast)
        let nodeColor: Color = task.isPast ? KindredTheme.faint : isLast ? KindredTheme.mint : isNow ? KindredTheme.amber : KindredTheme.accent

        return HStack(alignment: .top, spacing: 0) {
            // Time column
            Text(task.fireAt, format: .dateTime.hour().minute())
                .font(.caption.weight(.semibold)).monospacedDigit()
                .foregroundStyle(task.isPast ? KindredTheme.faint : nodeColor)
                .frame(width: 52, alignment: .leading)

            // Line + node
            VStack(spacing: 0) {
                if index > 0 {
                    Rectangle()
                        .fill(tasks[index - 1].isPast ? KindredTheme.faint.opacity(0.4) : KindredTheme.accent.opacity(0.3))
                        .frame(width: 2, height: 14)
                }
                ZStack {
                    Circle().fill(nodeColor.opacity(0.15)).frame(width: 22, height: 22)
                    Circle().fill(nodeColor).frame(width: isLast ? 12 : isNow ? 10 : 8, height: isLast ? 12 : isNow ? 10 : 8)
                    if isLast {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                if !isLast {
                    Rectangle()
                        .fill(task.isPast ? KindredTheme.faint.opacity(0.4) : KindredTheme.accent.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 24)

            // Task description
            VStack(alignment: .leading, spacing: 2) {
                Text(task.task)
                    .font(isLast ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundStyle(task.isPast ? KindredTheme.faint : KindredTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    if isNow && !task.isPast {
                        Text("Now")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(KindredTheme.amber)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(KindredTheme.amber.opacity(0.12), in: Capsule())
                    }
                    Text(beforeLabel(task.minutesBeforeServing) + (task.isPast ? " · done" : ""))
                        .font(.caption2).foregroundStyle(KindredTheme.faint)
                }
            }
            .padding(.leading, 10)
            .padding(.vertical, 10)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .background(isNow && !task.isPast ? KindredTheme.amber.opacity(0.04) : Color.clear)
    }

    private var actionButton: some View {
        VStack(spacing: 8) {
            Button { scheduleReminders() } label: {
                Label(didSchedule ? "Reminders set" : "Schedule reminders",
                      systemImage: didSchedule ? "checkmark.circle.fill" : "bell.badge.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(didSchedule ? KindredTheme.mint : KindredTheme.accent)
            .disabled(didSchedule)

            Text(didSchedule
                 ? "We'll remind you when to start each step — even if the app is closed."
                 : "Reminders arrive as notifications, even with the app closed.")
                .font(.caption).foregroundStyle(KindredTheme.faint)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func beforeLabel(_ minutes: Int) -> String {
        guard minutes > 0 else { return "at serving time" }
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h) hr \(m) min before" }
        if h > 0 { return "\(h) hr before" }
        return "\(m) min before"
    }

    private func scheduleReminders() {
        Task {
            guard await CookPlanner.requestPermission() else { showPermissionAlert = true; return }
            scheduledCount = await CookPlanner.schedule(recipe: recipe, serveTime: serveTime)
            didSchedule = true
        }
    }

    /// Default serve time: now + prep/cook + a 30-minute buffer.
    private static func defaultServeTime(for recipe: Recipe?) -> Date {
        let lead = (recipe?.totalMinutes ?? 60) + 30
        return Date().addingTimeInterval(TimeInterval(lead * 60))
    }
}
