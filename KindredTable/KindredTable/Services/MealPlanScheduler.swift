import Foundation
import UserNotifications

/// Schedules the week's dinner reminders as local notifications, keyed per
/// planned meal: a back-timed "start cooking" (and per-step) sequence from the
/// sit-down time, a "time to eat" ping, and a heads-up the evening before so the
/// cook can thaw or prep ahead. Reuses `CookPlanner.plan` for the task math.
enum MealPlanScheduler {

    static func requestPermission() async -> Bool { await CookPlanner.requestPermission() }

    /// Cancel every meal-plan notification, then reschedule all future meals.
    static func syncAll(_ meals: [PlannedMeal],
                        serveTime: (PlannedMeal) -> Date,
                        headcount: (PlannedMeal) -> Int) async {
        await cancelAll()
        for meal in meals {
            await schedule(meal, serveTime: serveTime(meal), headcount: headcount(meal))
        }
    }

    @discardableResult
    static func schedule(_ meal: PlannedMeal, serveTime: Date, headcount: Int, now: Date = Date()) async -> Int {
        let center = UNUserNotificationCenter.current()
        await cancel(meal)
        guard serveTime > now else { return 0 }

        // Scale the recipe to the night's headcount so timings/quantities match.
        let recipe = RecipeScaler.scaled(meal.recipe, to: headcount)
        var count = 0

        // Back-timed "start now" + per-step reminders.
        for (index, task) in CookPlanner.plan(for: recipe, serveTime: serveTime, now: now).enumerated() where !task.isPast {
            let content = UNMutableNotificationContent()
            content.title = recipe.title
            content.body = task.task
            content.sound = .default
            if let req = request(id: identifier(meal, index), content: content, fireAt: task.fireAt),
               (try? await center.add(req)) != nil { count += 1 }
        }

        // Time to eat.
        let eat = UNMutableNotificationContent()
        eat.title = recipe.title
        eat.body = "Time to plate up — enjoy dinner!"
        eat.sound = .default
        if let req = request(id: identifier(meal, -1), content: eat, fireAt: serveTime),
           (try? await center.add(req)) != nil { count += 1 }

        // Evening-before heads-up (prep ahead) — only fires when there's a night before.
        if let eve = eveningBefore(serveTime), eve > now {
            let content = UNMutableNotificationContent()
            content.title = "Tomorrow's dinner"
            content.body = "\(meal.recipe.title) for \(headcount) at \(timeString(serveTime)). Anything you can prep tonight?"
            content.sound = .default
            if let req = request(id: identifier(meal, -2), content: content, fireAt: eve),
               (try? await center.add(req)) != nil { count += 1 }
        }
        return count
    }

    /// Async so the pending-requests snapshot is awaited before we remove — and
    /// before any reschedule adds new ones — otherwise the late completion handler
    /// would wipe the notifications we just scheduled.
    static func cancel(_ meal: PlannedMeal) async {
        let center = UNUserNotificationCenter.current()
        let ids = (await center.pendingNotificationRequests())
            .map(\.identifier).filter { $0.hasPrefix(prefix(meal)) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let ids = (await center.pendingNotificationRequests())
            .map(\.identifier).filter { $0.hasPrefix(rootPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: Helpers

    /// 7pm the day before the sit-down time.
    private static func eveningBefore(_ serveTime: Date) -> Date? {
        let cal = Calendar.current
        guard let dayBefore = cal.date(byAdding: .day, value: -1, to: serveTime) else { return nil }
        return cal.date(bySettingHour: 19, minute: 0, second: 0, of: dayBefore)
    }

    private static func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
    }

    private static func request(id: String, content: UNMutableNotificationContent, fireAt: Date) -> UNNotificationRequest? {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        return UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        )
    }

    private static let rootPrefix = "kk.mealplan."
    private static func prefix(_ meal: PlannedMeal) -> String { "\(rootPrefix)\(meal.id.uuidString)." }
    private static func identifier(_ meal: PlannedMeal, _ index: Int) -> String { "\(prefix(meal))\(index)" }
}
