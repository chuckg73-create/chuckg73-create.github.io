import SwiftUI

/// The week's meal plan: seven days, the recipes planned for each, and one tap
/// to turn the whole week into a consolidated, aisle-sorted grocery list.
struct MealPlanView: View {
    @Environment(MealPlanStore.self) private var mealPlan
    @Environment(GroceryStore.self) private var grocery
    @Environment(SavedRecipeStore.self) private var saved
    @Environment(PantryStore.self) private var pantry
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(TasteFeedbackStore.self) private var feedback
    @Environment(RecentSuggestionsStore.self) private var recent
    @Environment(\.dismiss) private var dismiss

    private let service = GeminiRecipeService()
    @State private var addedCount: Int?
    @State private var isPlanning = false
    @State private var planError: String?
    // Dinner-time reminders + per-day editing
    @State private var usualTime = Date()
    @State private var remindersOn = false
    @State private var remindersMessage: String?
    @State private var editingTimeMeal: PlannedMeal?
    @State private var settingDinnerFor: DayRef?
    @State private var lastRemoved: PlannedMeal?
    @State private var swappingID: UUID?
    @State private var swapError: String?

    /// Identifiable wrapper so a day can drive a `.sheet(item:)`.
    private struct DayRef: Identifiable { let id = UUID(); let day: Date }

    private var days: [Date] { mealPlan.upcomingDays() }
    private var emptyDays: [Date] { days.filter { mealPlan.meals(on: $0).isEmpty } }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                if mealPlan.count(in: days) == 0 {
                    emptyState
                } else {
                    content
                }
                if let removed = lastRemoved {
                    VStack {
                        undoBanner(removed)
                        Spacer()
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("This week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                if mealPlan.count(in: days) > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        ShareLink(item: MealPlanShare.text(days: days, store: mealPlan)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share this week")
                    }
                }
            }
            .onAppear {
                usualTime = Calendar.current.date(bySettingHour: mealPlan.usualDinnerHour,
                                                  minute: mealPlan.usualDinnerMinute,
                                                  second: 0, of: Date()) ?? Date()
                mealPlan.materializeRecurring()
            }
            .sheet(item: $editingTimeMeal) { meal in
                DinnerTimeSheet(meal: meal, serveTime: mealPlan.serveTime(for: meal)) { Task { await resyncIfOn() } }
            }
            .sheet(item: $settingDinnerFor) { ref in
                SetDinnerSheet(day: ref.day) { Task { await resyncIfOn() } }
            }
        }
    }

    private func undoBanner(_ removed: PlannedMeal) -> some View {
        HStack(spacing: 10) {
            Text("Removed “\(removed.recipe.title)”")
                .font(.caption).foregroundStyle(KindredTheme.subtext).lineLimit(1)
            Spacer(minLength: 8)
            Button("Undo") {
                withAnimation { mealPlan.restore(removed); lastRemoved = nil }
                Task { await resyncIfOn() }
            }
            .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func removeMeal(_ meal: PlannedMeal) {
        withAnimation { lastRemoved = meal; mealPlan.remove(meal); addedCount = nil }
        Task { await resyncIfOn() }
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if lastRemoved?.id == meal.id { withAnimation { lastRemoved = nil } }
        }
    }

    private func swap(_ meal: PlannedMeal) {
        guard swappingID == nil else { return }
        swappingID = meal.id
        swapError = nil
        Task {
            do {
                let avoid = [recent.avoidBlock(), "Also avoid repeating: \(meal.recipe.title)."]
                    .compactMap { $0 }.joined(separator: "\n")
                let recipes = try await service.suggestRecipes(
                    from: pantry.ingredients,
                    profile: household.effectiveProfile(you: profileStore.profile),
                    count: 1,
                    servings: mealPlan.headcount(for: meal),
                    tasteFeedback: avoid,
                    useUpItems: pantry.useUpNames()
                )
                guard let recipe = recipes.first else {
                    await MainActor.run { swappingID = nil; swapError = "Couldn't find a swap right now — try again." }
                    return
                }
                await MainActor.run {
                    withAnimation { mealPlan.replace(meal, with: recipe) }
                    recent.record([recipe])
                    swappingID = nil
                }
                await resyncIfOn()
            } catch {
                await MainActor.run {
                    swappingID = nil
                    swapError = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            EmptyState(
                systemImage: "calendar",
                title: "Plan your week",
                message: "Let KindredTable fill your week with taste-matched dinners in one tap — or open any recipe and tap “Add to meal plan.”"
            )
            autoPlanButton.padding(.horizontal, 40)
            if let planError { Text(planError).font(.caption).foregroundStyle(KindredTheme.amber).padding(.horizontal, 40) }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    reminderHeader
                    if !emptyDays.isEmpty {
                        autoPlanButton
                        if let planError { Text(planError).font(.caption).foregroundStyle(KindredTheme.amber) }
                    }
                    if let swapError { Text(swapError).font(.caption).foregroundStyle(KindredTheme.amber) }
                    ForEach(days, id: \.self) { day in
                        daySection(day)
                    }
                    nutritionCard
                }
                .padding(20)
                .padding(.bottom, 90)
            }
            groceryBar
        }
    }

    /// Sets the usual sit-down time and turns on back-timed "start cooking" +
    /// evening-before prep reminders for the week.
    private var reminderHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Usual dinner time", systemImage: "clock")
                    .font(.subheadline.weight(.medium)).foregroundStyle(KindredTheme.text)
                Spacer()
                DatePicker("", selection: $usualTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            Button { Task { await toggleReminders() } } label: {
                Label(remindersMessage ?? (remindersOn ? "Reminders on — tap to turn off" : "Turn on dinner reminders"),
                      systemImage: remindersOn ? "bell.fill" : "bell.badge")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(remindersOn ? AnyShapeStyle(KindredTheme.mint) : AnyShapeStyle(KindredTheme.brandGradient),
                                in: Capsule())
            }
            .buttonStyle(.plain)
            Text("We'll tell you when to start each night so dinner lands at your sit-down time — plus a heads-up the evening before to prep ahead.")
                .font(.caption2).foregroundStyle(KindredTheme.faint).multilineTextAlignment(.center)
        }
        .padding(14)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(KindredTheme.hairline, lineWidth: 1))
        .onChange(of: usualTime) { _, newValue in
            mealPlan.setUsualDinnerTime(newValue)
            Task { await resyncIfOn() }
        }
    }

    private func scheduleWeek() async {
        guard await MealPlanScheduler.requestPermission() else {
            withAnimation { remindersMessage = "Enable notifications in Settings" }
            return
        }
        await MealPlanScheduler.syncAll(mealPlan.meals,
                                        serveTime: { mealPlan.serveTime(for: $0) },
                                        headcount: { mealPlan.headcount(for: $0) })
        remindersOn = true
        withAnimation { remindersMessage = "Reminders on for this week ✓" }
    }

    private func toggleReminders() async {
        guard remindersOn else { await scheduleWeek(); return }
        await MealPlanScheduler.cancelAll()
        remindersOn = false
        withAnimation { remindersMessage = nil }
    }

    /// Re-sync notifications after a change, but only once reminders are enabled.
    private func resyncIfOn() async {
        guard remindersOn else { return }
        await MealPlanScheduler.syncAll(mealPlan.meals,
                                        serveTime: { mealPlan.serveTime(for: $0) },
                                        headcount: { mealPlan.headcount(for: $0) })
    }

    /// One-tap: fill every empty upcoming day with a taste-matched dinner.
    private var autoPlanButton: some View {
        Button { planWeek() } label: {
            HStack(spacing: 8) {
                if isPlanning { ProgressView().controlSize(.small).tint(.white); Text("Planning your week…") }
                else { Image(systemName: "wand.and.stars"); Text("Auto-plan \(emptyDays.count) open day\(emptyDays.count == 1 ? "" : "s")") }
            }
            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 13)
            .foregroundStyle(.white)
            .background(KindredTheme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isPlanning || emptyDays.isEmpty)
    }

    private func planWeek() {
        let targets = emptyDays
        guard !targets.isEmpty else { return }
        guard !pantry.isEmpty else { planError = "Add a few ingredients in On Hand first so we can match your week."; return }
        planError = nil
        isPlanning = true
        Task {
            do {
                // Fold a variety instruction into the taste-feedback slot so a
                // week's plan doesn't come back as the same protein seven times.
                let variety = "VARIETY: this is a full week's plan — vary the proteins, cuisines and cooking methods across the recipes so no two dinners feel too similar."
                let planNote = [feedback.promptSummary(), variety, recent.avoidBlock()].compactMap { $0 }.joined(separator: "\n")
                let recipes = try await service.suggestRecipes(
                    from: pantry.ingredients,
                    profile: household.effectiveProfile(you: profileStore.profile),
                    count: targets.count,
                    servings: household.servings,
                    tasteFeedback: planNote,
                    useUpItems: pantry.useUpNames()
                )
                await MainActor.run {
                    for (day, recipe) in zip(targets, recipes) { mealPlan.add(recipe, to: day) }
                    recent.record(recipes)
                    addedCount = nil
                    isPlanning = false
                    if recipes.isEmpty { planError = "Couldn't build a plan right now — try again." }
                }
            } catch {
                await MainActor.run {
                    isPlanning = false
                    planError = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private func daySection(_ day: Date) -> some View {
        let meals = mealPlan.meals(on: day)
        let weekday = Calendar.current.component(.weekday, from: day)
        let theme = mealPlan.recurringTheme(for: weekday)
        let isRecurring = theme != nil && meals.first?.recipe.id == theme?.recipe.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Self.dayLabel(day)).font(.headline).foregroundStyle(KindredTheme.text)
                if isRecurring {
                    Button { mealPlan.clearRecurring(weekday: weekday) } label: {
                        Label("Repeats weekly", systemImage: "repeat")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(KindredTheme.mint)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button { settingDinnerFor = DayRef(day: day) } label: {
                    Label(meals.isEmpty ? "Set dinner" : "Change",
                          systemImage: "square.and.pencil")
                        .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.accent)
                }
                .buttonStyle(.plain)
            }
            if meals.isEmpty {
                Text("Nothing planned")
                    .font(.subheadline).foregroundStyle(KindredTheme.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .background(KindredTheme.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(meals) { meal in
                    NavigationLink {
                        RecipeDetailView(recipe: meal.recipe)
                    } label: {
                        mealRow(meal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func mealRow(_ meal: PlannedMeal) -> some View {
        let serve = mealPlan.serveTime(for: meal)
        let people = mealPlan.headcount(for: meal)
        let startBy = CookPlanner.plan(for: RecipeScaler.scaled(meal.recipe, to: people), serveTime: serve).first?.fireAt
        return HStack(spacing: 12) {
            RecipeHeroImage(recipe: meal.recipe, height: 52, glyphSize: 22)
                .frame(width: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(meal.recipe.title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(KindredTheme.text).lineLimit(1)
                HStack(spacing: 8) {
                    Label(Self.timeStr(serve), systemImage: "fork.knife")
                    Label("\(people)", systemImage: "person.2.fill")
                }
                .font(.caption).foregroundStyle(KindredTheme.subtext)
                if let startBy {
                    Text("Start by \(Self.timeStr(startBy))")
                        .font(.caption2.weight(.medium)).foregroundStyle(KindredTheme.accent)
                }
            }
            Spacer(minLength: 0)
            Button { swap(meal) } label: {
                if swappingID == meal.id {
                    ProgressView().tint(KindredTheme.accent)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(KindredTheme.accent)
                }
            }
            .buttonStyle(.plain)
            .disabled(swappingID != nil)
            .accessibilityLabel("Swap for another taste match")
            Button { editingTimeMeal = meal } label: {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(KindredTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set time and headcount")
            Button {
                removeMeal(meal)
            } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(KindredTheme.faint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(meal.recipe.title)")
        }
        .padding(10)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))
    }

    static func timeStr(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
    }

    /// At-a-glance average nutrition across the week's planned dinners.
    @ViewBuilder private var nutritionCard: some View {
        let recipes = days.flatMap { mealPlan.meals(on: $0) }.map(\.recipe)
        if let n = WeeklyNutrition.summarize(recipes) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(label: "This week's dinners")
                    Spacer()
                    Text("avg per serving").font(.caption2).foregroundStyle(KindredTheme.faint)
                }
                HStack(spacing: 10) {
                    nutritionStat("\(n.avgCalories)", "cal", KindredTheme.amber)
                    nutritionStat("\(n.avgProtein)g", "protein", KindredTheme.mint)
                    nutritionStat("\(n.avgCarbs)g", "carbs", KindredTheme.blue)
                    nutritionStat("\(n.avgFat)g", "fat", KindredTheme.coral)
                }
                Text("Averaged across \(n.count) planned dinner\(n.count == 1 ? "" : "s") with nutrition info. Estimates, not medical guidance.")
                    .font(.caption2).foregroundStyle(KindredTheme.faint)
            }
            .padding(16)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KindredTheme.hairline, lineWidth: 1))
        }
    }

    private func nutritionStat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundStyle(KindredTheme.text)
            Text(label).font(.caption2).foregroundStyle(KindredTheme.subtext)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var groceryBar: some View {
        let names = mealPlan.shoppingNames(for: days)
        let unique = Set(names.map { $0.lowercased() }).count
        return VStack(spacing: 6) {
            Button {
                let added = grocery.addMany(names)
                withAnimation { addedCount = added }
            } label: {
                Label(addedCount != nil ? "Added \(addedCount!) to grocery list" : "Add this week to grocery — \(unique) items",
                      systemImage: addedCount != nil ? "checkmark.circle.fill" : "cart.badge.plus")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(addedCount != nil ? AnyShapeStyle(KindredTheme.mint) : AnyShapeStyle(KindredTheme.brandGradient),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(unique == 0)
            Text("Combined across every planned recipe, sorted by aisle.")
                .font(.caption2).foregroundStyle(KindredTheme.faint)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: Date label

    static func dayLabel(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)),
           cal.isDate(date, inSameDayAs: tomorrow) { return "Tomorrow" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: date)
    }
}
