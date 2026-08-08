import SwiftUI
import UIKit

/// Full-screen, hands-free cooking view: one big step at a time, reads steps
/// aloud, listens for "next / back / repeat", keeps the screen awake, and stays
/// in sync with Siri via the shared CookingSession.
struct CookModeView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss

    private let session = CookingSession.shared
    @State private var voice = VoiceService()
    @State private var autoSpeak = true
    @State private var micOn = false
    @State private var showPermissionAlert = false

    var body: some View {
        ZStack {
            KindredBackground()
            VStack(spacing: 18) {
                topBar
                Spacer(minLength: 8)
                counter
                stepText
                Spacer(minLength: 8)
                controls
            }
            .padding(22)
        }
        .onAppear {
            session.start(title: recipe.title, steps: recipe.steps)
            UIApplication.shared.isIdleTimerDisabled = true
            if autoSpeak { voice.speak(session.spokenCurrent) }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            voice.stopListening()
            voice.stopSpeaking()
        }
        .alert("Microphone access needed", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow microphone and speech recognition in Settings to use hands-free voice commands. You can still tap the arrows or use Siri.")
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Label("Done", systemImage: "chevron.down").labelStyle(.titleAndIcon)
            }
            .foregroundStyle(KindredTheme.subtext)
            Spacer()
            Text(recipe.title).font(.subheadline.weight(.semibold))
                .lineLimit(1).foregroundStyle(KindredTheme.subtext)
            Spacer()
            Color.clear.frame(width: 52, height: 1)
        }
    }

    private var counter: some View {
        VStack(spacing: 10) {
            Text("Step \(session.stepNumber) of \(session.totalSteps)")
                .font(.headline).foregroundStyle(KindredTheme.accent)
            ProgressView(value: session.progress)
                .tint(KindredTheme.accent)
                .frame(maxWidth: 240)
        }
    }

    private var stepText: some View {
        ScrollView {
            Text(session.currentStep)
                .font(.system(size: 29, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(KindredTheme.text)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                circleButton("chevron.left", label: "Previous step", disabled: session.isFirstStep) { retreat(speak: autoSpeak) }
                micButton
                circleButton(session.isLastStep ? "checkmark" : "chevron.right",
                             label: session.isLastStep ? "Finish" : "Next step",
                             disabled: false) {
                    advance(speak: autoSpeak)
                }
            }

            HStack(spacing: 22) {
                Button {
                    autoSpeak.toggle()
                    if autoSpeak { voice.speak(session.spokenCurrent) } else { voice.stopSpeaking() }
                } label: {
                    Label(autoSpeak ? "Voice on" : "Voice off",
                          systemImage: autoSpeak ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                Button { voice.speak(session.spokenCurrent) } label: {
                    Label("Read step", systemImage: "play.circle")
                }
            }
            .font(.subheadline)
            .foregroundStyle(KindredTheme.subtext)

            if micOn, !voice.lastHeard.isEmpty {
                Text("“\(voice.lastHeard)”")
                    .font(.caption).foregroundStyle(KindredTheme.faint).lineLimit(1)
            }
            Text("Say \"next\", \"back\", or \"repeat\" — or ask Siri \"next step in Kindred Kitchen.\"")
                .font(.caption2)
                .foregroundStyle(KindredTheme.faint)
                .multilineTextAlignment(.center)
        }
    }

    private var micButton: some View {
        Button { toggleMic() } label: {
            VStack(spacing: 4) {
                Image(systemName: micOn ? "mic.fill" : "mic.slash.fill").font(.title2)
                Text(micOn ? "Listening…" : "Hands-free").font(.caption2)
            }
            .foregroundStyle(micOn ? KindredTheme.background : KindredTheme.accent)
            .frame(width: 104, height: 72)
            .background(
                micOn ? AnyShapeStyle(KindredTheme.brandGradient) : AnyShapeStyle(KindredTheme.card),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
    }

    private func circleButton(_ icon: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title2.bold())
                .foregroundStyle(disabled ? KindredTheme.faint : KindredTheme.text)
                .frame(width: 64, height: 64)
                .background(KindredTheme.card, in: Circle())
        }
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    // MARK: Navigation

    private func advance(speak: Bool) {
        if session.isLastStep {
            voice.speak("That's the last step. Enjoy your \(recipe.title)!")
            return
        }
        _ = session.next()
        if speak { voice.speak(session.spokenCurrent) }
    }

    private func retreat(speak: Bool) {
        _ = session.previous()
        if speak { voice.speak(session.spokenCurrent) }
    }

    private func toggleMic() {
        if micOn {
            voice.stopListening()
            micOn = false
            return
        }
        Task {
            if await voice.requestPermissions() {
                voice.startListening { command in handle(command) }
                micOn = true
            } else {
                showPermissionAlert = true
            }
        }
    }

    private func handle(_ command: VoiceCommand) {
        switch command {
        case .next: advance(speak: true)
        case .previous: retreat(speak: true)
        case .repeatStep: voice.speak(session.spokenCurrent)
        case .stop:
            voice.stopListening(); micOn = false
        }
    }
}
