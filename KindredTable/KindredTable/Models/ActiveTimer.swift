import Foundation

/// A named countdown timer running in Cook Mode. Multiple can run at once.
struct ActiveTimer: Identifiable {
    let id = UUID()
    var label: String
    var totalSeconds: Int
    var remaining: Int
    var isRunning: Bool = true
    var isFinished: Bool { remaining <= 0 }

    init(label: String, seconds: Int) {
        self.label = label
        self.totalSeconds = seconds
        self.remaining = seconds
    }
}
