import Foundation
import Observation

/// The currently-cooking recipe and step, shared by Cook Mode and Siri intents.
/// Persisted to UserDefaults so a Siri "next step" works even when the app is
/// backgrounded (or was relaunched). On-device only.
@MainActor
@Observable
final class CookingSession {
    static let shared = CookingSession()

    private(set) var title: String = ""
    private(set) var steps: [String] = []
    private(set) var index: Int = 0

    private let defaults = UserDefaults.standard
    private let key = "kk.cooking.session.v1"

    private init() { reload() }

    private struct Snapshot: Codable {
        var title: String
        var steps: [String]
        var index: Int
    }

    var isActive: Bool { !steps.isEmpty }
    var totalSteps: Int { steps.count }
    var stepNumber: Int { steps.isEmpty ? 0 : min(index + 1, steps.count) }
    var currentStep: String { steps.indices.contains(index) ? steps[index] : "" }
    var isFirstStep: Bool { index <= 0 }
    var isLastStep: Bool { index >= steps.count - 1 }
    var progress: Double { steps.isEmpty ? 0 : Double(index + 1) / Double(steps.count) }

    func start(title: String, steps: [String]) {
        self.title = title
        self.steps = steps
        self.index = 0
        persist()
    }

    @discardableResult func next() -> Bool {
        guard index < steps.count - 1 else { return false }
        index += 1; persist(); return true
    }

    @discardableResult func previous() -> Bool {
        guard index > 0 else { return false }
        index -= 1; persist(); return true
    }

    func goTo(_ i: Int) {
        guard steps.indices.contains(i) else { return }
        index = i; persist()
    }

    func finish() {
        title = ""; steps = []; index = 0; persist()
    }

    /// Re-read from disk — call when returning to the foreground, in case a Siri
    /// intent advanced the session in another process.
    func reload() {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        title = snapshot.title
        steps = snapshot.steps
        index = snapshot.index
    }

    // MARK: Spoken responses (used by voice + Siri)

    var spokenCurrent: String {
        guard isActive else { return "You're not cooking anything right now. Open a recipe and start Cook Mode." }
        return "Step \(stepNumber) of \(totalSteps). \(currentStep)"
    }

    var spokenNext: String {
        guard isActive else { return spokenCurrent }
        if next() { return spokenCurrent }
        return "That was the last step — enjoy your \(title.isEmpty ? "meal" : title)!"
    }

    var spokenPrevious: String {
        guard isActive else { return spokenCurrent }
        _ = previous()
        return spokenCurrent
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(Snapshot(title: title, steps: steps, index: index)) {
            defaults.set(data, forKey: key)
        }
    }
}
