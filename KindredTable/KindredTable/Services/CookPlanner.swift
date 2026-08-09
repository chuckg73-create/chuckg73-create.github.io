import Foundation
import UserNotifications

/// Schedules "cook by a time" reminders as local notifications so the cook is
/// told when to start each task — even with the app closed — so every component
/// of a meal finishes together.
enum CookPlanner {

    /// A concrete reminder: what to do and the clock time it should fire.
    struct ScheduledTask: Identifiable, Hashable {
        let id = UUID()
        var task: String
        var fireAt: Date
        var minutesBeforeServing: Int
        var isPast: Bool
    }

    /// The tasks to schedule for a recipe + serve time (earliest first). Falls
    /// back to a single "start cooking" reminder when the recipe has no timeline.
    static func plan(for recipe: Recipe, serveTime: Date, now: Date = Date()) -> [ScheduledTask] {
        let items = recipe.timeline.isEmpty
            ? [TimelineTask(task: "Start cooking — \(recipe.title)", minutesBeforeServing: max(recipe.totalMinutes, 1))]
            : recipe.timeline
        return items
            .map { t in
                let fire = serveTime.addingTimeInterval(TimeInterval(-t.minutesBeforeServing * 60))
                return ScheduledTask(task: t.task, fireAt: fire,
                                     minutesBeforeServing: t.minutesBeforeServing, isPast: fire < now)
            }
            .sorted { $0.fireAt < $1.fireAt }
    }

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Schedule reminders for the still-in-the-future tasks (plus a "time to
    /// eat" ping). Returns how many were scheduled.
    @discardableResult
    static func schedule(recipe: Recipe, serveTime: Date) async -> Int {
        let center = UNUserNotificationCenter.current()
        cancel(recipe: recipe)

        var count = 0
        for (index, task) in plan(for: recipe, serveTime: serveTime).enumerated() where !task.isPast {
            let content = UNMutableNotificationContent()
            content.title = recipe.title
            content.body = task.task
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.fireAt)
            let request = UNNotificationRequest(
                identifier: identifier(recipe: recipe, index: index),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            if (try? await center.add(request)) != nil { count += 1 }
        }

        if serveTime > Date() {
            let content = UNMutableNotificationContent()
            content.title = recipe.title
            content.body = "It's time to plate up — enjoy your meal!"
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: serveTime)
            let request = UNNotificationRequest(
                identifier: identifier(recipe: recipe, index: -1),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            if (try? await center.add(request)) != nil { count += 1 }
        }
        return count
    }

    static func cancel(recipe: Recipe) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix(recipe: recipe)) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func prefix(recipe: Recipe) -> String { "kk.plan.\(recipe.id.uuidString)." }
    private static func identifier(recipe: Recipe, index: Int) -> String { "\(prefix(recipe: recipe))\(index)" }
}
