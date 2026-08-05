import SwiftUI
import UIKit

/// Presented after a photo is analysed. Lets the user confirm which detected
/// ingredients to keep and add any the recogniser missed, before they land in
/// the pantry.
struct IngredientReviewSheet: View {
    var image: UIImage?
    var detected: [Ingredient]
    var onConfirm: ([Ingredient]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var items: [ReviewItem] = []
    @State private var newName = ""

    private struct ReviewItem: Identifiable {
        let id = UUID()
        var ingredient: Ingredient
        var include: Bool
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                List {
                    if let image {
                        Section {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }

                    Section {
                        addRow
                    } header: {
                        Text(detected.isEmpty ? "Add ingredients" : "Detected \(detected.count) — tap to include")
                    }

                    Section {
                        ForEach($items) { $item in
                            reviewRow($item)
                        }
                        .onDelete { offsets in items.remove(atOffsets: offsets) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedCount)") {
                        onConfirm(items.filter(\.include).map(\.ingredient))
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedCount == 0)
                }
            }
            .onAppear {
                if items.isEmpty {
                    items = detected.map { ReviewItem(ingredient: $0, include: true) }
                }
            }
        }
    }

    private var selectedCount: Int { items.filter(\.include).count }

    private var addRow: some View {
        HStack {
            Image(systemName: "plus.circle.fill").foregroundStyle(KindredTheme.accent)
            TextField("Add an ingredient", text: $newName)
                .textInputAutocapitalization(.words)
                .onSubmit(addManual)
            if !newName.isEmpty {
                Button("Add", action: addManual).font(.subheadline)
            }
        }
        .listRowBackground(KindredTheme.card)
    }

    private func reviewRow(_ item: Binding<ReviewItem>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.wrappedValue.ingredient.category.systemImage)
                .foregroundStyle(KindredTheme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.wrappedValue.ingredient.name)
                HStack(spacing: 6) {
                    Text(item.wrappedValue.ingredient.category.title)
                    if let c = item.wrappedValue.ingredient.confidence {
                        Text("· \(Int(c * 100))% sure")
                    }
                }
                .font(.caption)
                .foregroundStyle(KindredTheme.faint)
            }
            Spacer()
            Button {
                item.include.wrappedValue.toggle()
            } label: {
                Image(systemName: item.wrappedValue.include ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.wrappedValue.include ? KindredTheme.mint : KindredTheme.faint)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(KindredTheme.card)
    }

    private func addManual() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let ingredient = Ingredient(name: trimmed, category: FoodVocabulary.categorize(trimmed))
        items.insert(ReviewItem(ingredient: ingredient, include: true), at: 0)
        newName = ""
    }
}

#Preview {
    IngredientReviewSheet(image: nil, detected: SampleData.ingredients, onConfirm: { _ in })
        .preferredColorScheme(.dark)
}
