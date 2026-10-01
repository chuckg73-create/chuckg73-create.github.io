import Foundation
import UserNotifications

/// Schedules a daily 5 pm "what's for dinner?" notification that mentions the
/// cook's top pantry items so the nudge feels personal, not generic.
/// Reschedule whenever the pantry changes so the body stays fresh.
enum DinnerNudgeService {

    static let notificationID = "kt.dinner.nudge"
    static let enabledKey     = "kt_dinner_nudge_enabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    // MARK: Public

    /// Ask for permission then schedule. Call when the user first enables the toggle.
    @discardableResult
    static func enable(pantryItems: [Ingredient]) async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        isEnabled = true
        await reschedule(pantryItems: pantryItems)
        return true
    }

    /// Silent reschedule — call on every pantry save to keep the body fresh.
    /// No-ops if the user hasn't enabled the nudge or permission was revoked.
    static func reschedule(pantryItems: [Ingredient]) async {
        guard isEnabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        let content = UNMutableNotificationContent()
        content.title = "What's for dinner?"
        content.body  = nudgeBody(for: pantryItems)
        content.sound = .default

        var comps = DateComponents()
        comps.hour   = 17
        comps.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: notificationID,
                                            content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Remove the notification and mark disabled.
    static func disable() {
        isEnabled = false
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    // MARK: Private

    private static func nudgeBody(for items: [Ingredient]) -> String {
        // 1. If tonight's dinner is already planned, lead with that.
        if let plan = UserDefaults(suiteName: "group.com.kindred.KindredTable")?
            .dictionary(forKey: "kt.tonight.plan") as? [String: String],
           let title = plan["title"] {
            return "Time to make \(title). Tap to start cooking."
        }

        // 2. If perishables need using up, focus the nudge there.
        let aging = items
            .filter { $0.freshness(now: Date()).needsAttention && $0.category != .frozen }
            .prefix(2)
            .map { $0.name.lowercased() }
        if !aging.isEmpty {
            let names = aging.count == 1 ? aging[0] : "\(aging[0]) and \(aging[1])"
            return "Your \(names) won't keep much longer — tap for quick ideas to use them tonight."
        }

        // 3. Fall back to top pantry items.
        let picks = items
            .filter { $0.category != .frozen }
            .prefix(3)
            .map { $0.name.lowercased() }

        guard !picks.isEmpty else {
            return "Time to plan tonight's dinner. Tap to get ideas."
        }

        switch picks.count {
        case 1:
            return "You have \(picks[0]). Tap to see what you can make tonight."
        case 2:
            return "You have \(picks[0]) and \(picks[1]). Tap to get tonight's ideas."
        default:
            return "You have \(picks[0]), \(picks[1]), and \(picks[2]). Tap to get tonight's ideas."
        }
    }
}
