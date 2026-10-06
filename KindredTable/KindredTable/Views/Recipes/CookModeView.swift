import SwiftUI
import UIKit
import AudioToolbox
import PhotosUI

/// Full-screen, hands-free cooking view: one big step at a time, reads steps
/// aloud, listens for "next / back / repeat", keeps the screen awake, and stays
/// in sync with Siri via the shared CookingSession.
struct CookModeView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @Environment(TasteFeedbackStore.self) private var feedback
    @Environment(RecentSuggestionsStore.self) private var recent
    @Environment(PantryStore.self) private var pantry
    @Environment(SavedRecipeStore.self) private var cookbook

    private let gemini = GeminiRecipeService()
    private let session = CookingSession.shared

    @State private var showFinishRating = false
    @State private var showDepletionOffer = false
    @State private var showManualTimer = false
    @State private var manualMinutes = 5
    @State private var voice = VoiceService()
    @State private var autoSpeak = true
    @State private var micOn = false
    @State private var showPermissionAlert = false

    // Multi-timer
    @State private var activeTimers: [ActiveTimer] = []
    /// Per-step auto-detected timer (tracks whether we already offered it).
    @State private var stepTimerStarted = false

    // In-cook substitution
    @State private var showSubstitution = false
    @State private var subIngredient = ""
    @State private var subAnswer: String?
    @State private var subLoading = false

    // Technique look-up
    @State private var techniqueQuery: String?

    // Finished dish photo
    @State private var showDishPhotoOptions = false
    @State private var dishPhotoItem: PhotosPickerItem?
    @State private var dishPhotoData: Data?

    private var stepSeconds: Int? { StepDuration.seconds(in: session.currentStep) }

    /// Pantry items the recipe used (haveIt == true) that can now be cleared.
    private var depletableItems: [Ingredient] {
        let usedNames = Set(recipe.ingredients.filter(\.haveIt).map { $0.name.lowercased() })
        return pantry.ingredients.filter { usedNames.contains($0.name.lowercased()) }
    }

    var body: some View {
        ZStack {
            KindredBackground()
            VStack(spacing: 18) {
                topBar
                Spacer(minLength: 8)
                counter
                stepText
                timerChip
                if !activeTimers.isEmpty { activeTimersPanel }
                quickActions
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
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in tick() }
        .onChange(of: session.stepNumber) { _, _ in stepTimerStarted = false }
        .onChange(of: dishPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    dishPhotoData = data
                    saveDishPhoto(data)
                }
            }
        }
        .confirmationDialog("How did it turn out?", isPresented: $showFinishRating, titleVisibility: .visible) {
            ForEach(RecipeVerdict.allCases) { v in
                Button(v.title) {
                    feedback.record(recipe, verdict: v)
                    if v == .disliked { recent.record([recipe]) }
                    let canOffer = (v == .loved || v == .liked) && !depletableItems.isEmpty
                    if canOffer { showDepletionOffer = true } else { dismiss() }
                }
            }
            Button("Skip", role: .cancel) { dismiss() }
        } message: {
            Text("Rating helps KindredTable match your taste next time.")
        }
        .alert("Remove used ingredients?", isPresented: $showDepletionOffer) {
            Button("Remove from pantry") {
                depletableItems.forEach { pantry.remove($0) }
                showDishPhotoOptions = true
            }
            Button("Keep them", role: .cancel) { showDishPhotoOptions = true }
        } message: {
            let names = depletableItems.prefix(3).map(\.name).joined(separator: ", ")
            Text("Clear \(names) from your pantry since you just cooked them.")
        }
        .confirmationDialog("Save a photo of your dish?", isPresented: $showDishPhotoOptions, titleVisibility: .visible) {
            PhotosPicker(selection: $dishPhotoItem, matching: .images) {
                Text("Choose from Photos")
            }
            Button("Skip") { dismiss() }
        }
        .photosPicker(isPresented: .constant(false), selection: $dishPhotoItem)
        .sheet(isPresented: $showManualTimer) {
            ManualTimerSheet(selectedMinutes: $manualMinutes) { label in
                activeTimers.append(ActiveTimer(label: label, seconds: manualMinutes * 60))
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSubstitution) {
            SubstitutionSheet(
                recipe: recipe,
                currentStep: session.currentStep,
                ingredient: $subIngredient,
                answer: $subAnswer,
                isLoading: $subLoading,
                gemini: gemini
            )
            .presentationDetents([.medium, .large])
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

    @ViewBuilder private var timerChip: some View {
        if let total = stepSeconds, !stepTimerStarted {
            // Auto-detected step duration — offer to start it.
            Button {
                let label = "Step \(session.stepNumber)"
                activeTimers.append(ActiveTimer(label: label, seconds: total))
                stepTimerStarted = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "timer").foregroundStyle(KindredTheme.amber)
                    Text("Timer for this step").font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    Spacer()
                    Label("Start \(StepDuration.clock(total))", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(KindredTheme.warmGradient, in: Capsule())
                }
                .chipFrame
            }
            .buttonStyle(.plain)
        } else if stepSeconds == nil {
            // No detected time — offer a manual timer.
            Button { showManualTimer = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "timer").foregroundStyle(KindredTheme.faint)
                    Text("Set a timer for this step")
                        .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                    Spacer()
                    Text("Set").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .foregroundStyle(KindredTheme.accent)
                        .background(KindredTheme.accent.opacity(0.14), in: Capsule())
                }
                .chipFrame
            }
            .buttonStyle(.plain)
        }
    }

    /// Running timers panel — shows all active timers below the step chip.
    private var activeTimersPanel: some View {
        VStack(spacing: 8) {
            ForEach($activeTimers) { $timer in
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .foregroundStyle(timer.isFinished ? KindredTheme.coral : KindredTheme.amber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timer.label).font(.caption).foregroundStyle(KindredTheme.faint)
                        Text(StepDuration.clock(timer.remaining))
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(timer.isFinished ? KindredTheme.coral : KindredTheme.text)
                    }
                    Spacer()
                    if timer.isFinished {
                        Text("Done!").font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.coral)
                    } else {
                        Button { timer.isRunning.toggle() } label: {
                            Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                                .font(.title3).foregroundStyle(KindredTheme.accent)
                        }
                    }
                    Button {
                        activeTimers.removeAll { $0.id == timer.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(KindredTheme.faint)
                    }
                }
                .chipFrame
            }
        }
    }

    /// Quick-action row: substitution + add another timer + technique lookup.
    private var quickActions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button { showSubstitution = true } label: {
                    Label("Substitute", systemImage: "arrow.2.squarepath")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(KindredTheme.accent)
                        .background(KindredTheme.accent.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { showManualTimer = true } label: {
                    Label("Add timer", systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(KindredTheme.subtext)
                        .background(KindredTheme.card,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(KindredTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            if let keyword = detectedTechnique(in: session.currentStep) {
                Button { techniqueQuery = keyword } label: {
                    Label("How to \(keyword)?", systemImage: "book.pages.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(KindredTheme.blue)
                        .background(KindredTheme.blue.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(KindredTheme.blue.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: session.stepNumber)
        .sheet(isPresented: Binding(
            get: { techniqueQuery != nil },
            set: { if !$0 { techniqueQuery = nil } }
        )) {
            if let q = techniqueQuery {
                NavigationStack { TechniqueDetailView(query: q) }
            }
        }
    }

    /// Scans a step string for recognisable technique keywords and returns a
    /// short human-readable phrase to look up if one is found.
    private func detectedTechnique(in step: String) -> String? {
        let lower = step.lowercased()
        let pairs: [(keyword: String, label: String)] = [
            ("julienne", "julienne vegetables"),
            ("brunoise", "brunoise dice"),
            ("chiffonade", "chiffonade herbs"),
            ("deglaze", "deglaze a pan"),
            ("blanch", "blanch vegetables"),
            ("beurre blanc", "make a beurre blanc"),
            ("brine", "brine chicken"),
            ("render", "render fat"),
            ("emulsif", "emulsify a sauce"),
            ("temper", "temper chocolate"),
            ("proof", "proof yeast"),
            ("knead", "knead dough"),
            ("fold in", "fold egg whites into batter"),
            ("soft.?boil", "soft boil an egg"),
            ("hard.?boil", "hard boil an egg"),
            ("poach", "poach an egg"),
            ("caramel", "make caramel"),
            ("sear", "sear meat"),
            ("roux", "make a roux"),
        ]
        for pair in pairs {
            if lower.range(of: pair.keyword, options: .regularExpression) != nil {
                return pair.label
            }
        }
        return nil
    }

    private func tick() {
        var anyFinishedNow = false
        for i in activeTimers.indices {
            guard activeTimers[i].isRunning, !activeTimers[i].isFinished else { continue }
            activeTimers[i].remaining -= 1
            if activeTimers[i].remaining <= 0 {
                activeTimers[i].remaining = 0
                activeTimers[i].isRunning = false
                anyFinishedNow = true
            }
        }
        if anyFinishedNow { timerFinished() }
    }

    private func timerFinished() {
        AudioServicesPlaySystemSound(1005)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        voice.speak("Time's up!")
    }

    private func saveDishPhoto(_ data: Data) {
        var updated = recipe
        // Store photo on disk keyed by recipe ID; signal cookbook to update.
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dish_photos")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(recipe.id.uuidString).jpg")
        try? data.write(to: file)
        updated.imageURL = file.absoluteString
        cookbook.add(updated)
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
            Text("Say \"next\", \"back\", or \"repeat\" — or ask Siri \"next step in KindredTable.\"")
                .font(.caption2)
                .foregroundStyle(KindredTheme.faint)
                .multilineTextAlignment(.center)

            if VoiceService.usingBasicVoice {
                Label("For a more natural voice, download an Enhanced English voice in Settings ▸ Accessibility ▸ Spoken Content ▸ Voices.",
                      systemImage: "waveform")
                    .font(.caption2)
                    .foregroundStyle(KindredTheme.accent)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
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
            showFinishRating = true
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

// MARK: - Manual Timer Sheet

private struct ManualTimerSheet: View {
    @Binding var selectedMinutes: Int
    var onStart: (_ label: String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var labelText = ""

    private let presets = [1, 2, 5, 10, 15, 20, 30]

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                VStack(spacing: 28) {
                    VStack(spacing: 16) {
                        HStack(spacing: 24) {
                            Button {
                                if selectedMinutes > 1 { selectedMinutes -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 36)).foregroundStyle(KindredTheme.accent)
                            }
                            Text("\(selectedMinutes) min")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundStyle(KindredTheme.text)
                                .frame(minWidth: 130)
                                .contentTransition(.numericText())
                            Button {
                                if selectedMinutes < 90 { selectedMinutes += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 36)).foregroundStyle(KindredTheme.accent)
                            }
                        }
                        // Quick presets
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presets, id: \.self) { p in
                                    Button("\(p)m") { withAnimation(.easeOut(duration: 0.15)) { selectedMinutes = p } }
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .foregroundStyle(selectedMinutes == p ? Color.white : KindredTheme.subtext)
                                        .background(selectedMinutes == p ? AnyShapeStyle(KindredTheme.brandGradient)
                                                    : AnyShapeStyle(KindredTheme.card), in: Capsule())
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    TextField("Label (optional)", text: $labelText)
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundStyle(KindredTheme.text)
                        .padding(.horizontal, 30)

                    Button {
                        let label = labelText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onStart(label.isEmpty ? "\(selectedMinutes) min" : label)
                        dismiss()
                    } label: {
                        Label("Start \(selectedMinutes) min timer", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(KindredTheme.warmGradient, in: Capsule())
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.vertical, 30)
            }
            .navigationTitle("Set a timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Substitution sheet

private struct SubstitutionSheet: View {
    let recipe: Recipe
    let currentStep: String
    @Binding var ingredient: String
    @Binding var answer: String?
    @Binding var isLoading: Bool
    let gemini: GeminiRecipeService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What are you missing?")
                            .font(.headline).foregroundStyle(KindredTheme.text)
                        HStack(spacing: 10) {
                            TextField("e.g. heavy cream, butter, eggs", text: $ingredient)
                                .focused($focused)
                                .submitLabel(.go)
                                .onSubmit { ask() }
                                .padding(12)
                                .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(KindredTheme.hairline, lineWidth: 1))
                            Button(action: ask) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2).foregroundStyle(ingredient.isEmpty ? KindredTheme.faint : KindredTheme.accent)
                            }
                            .disabled(ingredient.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                        }
                    }

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView().tint(KindredTheme.accent)
                            Text("Thinking…").foregroundStyle(KindredTheme.subtext)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let answer {
                        KindredCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Substitution", systemImage: "arrow.2.squarepath")
                                    .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.accent)
                                Text(answer)
                                    .font(.body).foregroundStyle(KindredTheme.text)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Substitute an ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .onAppear { focused = true }
        }
    }

    private func ask() {
        let q = ingredient.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !isLoading else { return }
        focused = false
        isLoading = true
        answer = nil
        Task {
            let result = try? await gemini.substitute(ingredient: q, inStep: currentStep, recipe: recipe)
            await MainActor.run {
                answer = result ?? "I couldn't find a substitution right now. Try using less of the ingredient or omitting it if it's a garnish."
                isLoading = false
            }
        }
    }
}

// MARK: - View helper

private extension View {
    var chipFrame: some View {
        self
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KindredTheme.hairline, lineWidth: 1))
            .padding(.horizontal, 6)
    }
}
