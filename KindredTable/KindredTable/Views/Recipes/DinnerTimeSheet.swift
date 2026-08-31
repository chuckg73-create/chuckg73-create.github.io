import SwiftUI

/// Set a night's sit-down time and how many are eating. Shows the back-timed
/// "start cooking by" so the cook can see when they'll need to be in the kitchen.
struct DinnerTimeSheet: View {
    let meal: PlannedMeal
    var onChange: () -> Void

    @Environment(MealPlanStore.self) private var mealPlan
    @Environment(\.dismiss) private var dismiss

    @State private var time: Date
    @State private var count: Int

    /// `serveTime` is the meal's resolved sit-down time (its override, or the
    /// cook's usual dinner time) — never the start-of-day, so the picker doesn't
    /// default to midnight.
    init(meal: PlannedMeal, serveTime: Date, onChange: @escaping () -> Void) {
        self.meal = meal
        self.onChange = onChange
        _time = State(initialValue: serveTime)
        _count = State(initialValue: meal.headcount ?? max(1, meal.recipe.servings))
    }

    /// The picked time-of-day applied to this meal's day.
    private var serveDateTime: Date {
        let cal = Calendar.current
        let hm = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: hm.hour ?? 18, minute: hm.minute ?? 30, second: 0, of: meal.date) ?? meal.date
    }

    private var startBy: Date? {
        CookPlanner.plan(for: RecipeScaler.scaled(meal.recipe, to: count), serveTime: serveDateTime).first?.fireAt
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                Form {
                    Section {
                        DatePicker("Sit down at", selection: $time, displayedComponents: .hourAndMinute)
                        Stepper("\(count) \(count == 1 ? "person" : "people") eating", value: $count, in: 1...12)
                    } header: {
                        Text(MealPlanView.dayLabel(meal.date))
                    }
                    .listRowBackground(KindredTheme.card)

                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "flame.fill").foregroundStyle(KindredTheme.amber)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start cooking by \(startBy.map(MealPlanView.timeStr) ?? "—")")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.text)
                                Text("So \(meal.recipe.title) is ready at \(MealPlanView.timeStr(serveDateTime)).")
                                    .font(.caption).foregroundStyle(KindredTheme.subtext)
                            }
                        }
                    }
                    .listRowBackground(KindredTheme.card)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Dinner time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        mealPlan.setServeTime(serveDateTime, for: meal)
                        mealPlan.setHeadcount(count, for: meal)
                        onChange()
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
        }
    }
}
