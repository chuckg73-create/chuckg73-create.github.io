import AppIntents

// Siri / Shortcuts control for hands-free cooking. Each intent reads the shared
// CookingSession (persisted), advances it, and speaks the step back.

struct WhatsMyStepIntent: AppIntent {
    static var title: LocalizedStringResource = "What's My Step"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        CookingSession.shared.reload()
        return .result(dialog: IntentDialog(stringLiteral: CookingSession.shared.spokenCurrent))
    }
}

struct NextStepIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Step"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        CookingSession.shared.reload()
        return .result(dialog: IntentDialog(stringLiteral: CookingSession.shared.spokenNext))
    }
}

struct PreviousStepIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Step"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        CookingSession.shared.reload()
        return .result(dialog: IntentDialog(stringLiteral: CookingSession.shared.spokenPrevious))
    }
}

struct RepeatStepIntent: AppIntent {
    static var title: LocalizedStringResource = "Repeat Step"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        CookingSession.shared.reload()
        return .result(dialog: IntentDialog(stringLiteral: CookingSession.shared.spokenCurrent))
    }
}

/// Registers the Siri phrases. Users say e.g. "Hey Siri, next step in Kindred
/// Kitchen". `\(.applicationName)` resolves to the app's display name.
struct KindredKitchenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhatsMyStepIntent(),
            phrases: [
                "What's my step in \(.applicationName)",
                "What's my next step in \(.applicationName)",
                "\(.applicationName) what's my step"
            ],
            shortTitle: "Current step",
            systemImageName: "list.number"
        )
        AppShortcut(
            intent: NextStepIntent(),
            phrases: [
                "Next step in \(.applicationName)",
                "\(.applicationName) next step"
            ],
            shortTitle: "Next step",
            systemImageName: "arrow.right.circle"
        )
        AppShortcut(
            intent: PreviousStepIntent(),
            phrases: [
                "Previous step in \(.applicationName)",
                "\(.applicationName) previous step"
            ],
            shortTitle: "Previous step",
            systemImageName: "arrow.left.circle"
        )
        AppShortcut(
            intent: RepeatStepIntent(),
            phrases: [
                "Repeat step in \(.applicationName)",
                "\(.applicationName) repeat step"
            ],
            shortTitle: "Repeat step",
            systemImageName: "arrow.clockwise.circle"
        )
    }
}
