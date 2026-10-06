import SwiftUI

struct TechniquesView: View {
    @State private var query = ""
    @State private var navigateTo: IdentifiableString?
    @FocusState private var searchFocused: Bool

    private let categories: [(title: String, icon: String, tint: Color, techniques: [String])] = [
        ("Eggs", "bird", KindredTheme.amber, [
            "Soft boil an egg", "Hard boil an egg", "Poach an egg",
            "Make a French omelette", "Sunny side up egg", "Scrambled eggs"
        ]),
        ("Knife skills", "scissors", KindredTheme.coral, [
            "Julienne vegetables", "Brunoise dice", "Chiffonade herbs",
            "Fillet a fish", "Butcher a whole chicken", "Mince garlic"
        ]),
        ("Meat", "flame.fill", KindredTheme.coral, [
            "Sear a steak", "Rest meat after cooking", "Brine chicken",
            "Spatchcock a chicken", "Make a pan sauce", "Render bacon fat"
        ]),
        ("Sauces & basics", "drop.fill", KindredTheme.blue, [
            "Make a roux", "Deglaze a pan", "Emulsify a vinaigrette",
            "Make a beurre blanc", "Reduce a sauce", "Make stock"
        ]),
        ("Baking", "birthday.cake.fill", KindredTheme.accent, [
            "Proof yeast", "Knead bread dough", "Blind bake a pie crust",
            "Temper chocolate", "Make caramel", "Fold egg whites into batter"
        ]),
        ("Heat & technique", "thermometer.medium", KindredTheme.mint, [
            "Deep fry safely", "Steam vegetables properly", "Blanch and shock",
            "Caramelize onions", "Toast spices", "Roast garlic"
        ]),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        searchBar
                        if query.trimmingCharacters(in: .whitespaces).isEmpty {
                            ForEach(categories, id: \.title) { cat in
                                categorySection(cat)
                            }
                        } else {
                            searchResults
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Techniques")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $navigateTo) { s in
                TechniqueDetailView(query: s.value)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(KindredTheme.faint)
            TextField("How do I fillet a fish?", text: $query)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit {
                    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !q.isEmpty else { return }
                    navigateTo = IdentifiableString(q)
                }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(KindredTheme.faint)
                }
            }
        }
        .padding(13)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(KindredTheme.hairline, lineWidth: 1))
    }

    private var searchResults: some View {
        let q = query.lowercased()
        let all = categories.flatMap(\.techniques)
        let matches = all.filter { $0.lowercased().contains(q) }
        return VStack(spacing: 0) {
            if matches.isEmpty {
                // Ask Gemini about anything not in the preset list
                Button {
                    navigateTo = IdentifiableString(query.trimmingCharacters(in: .whitespacesAndNewlines))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title3).foregroundStyle(KindredTheme.accent)
                            .frame(width: 38, height: 38)
                            .background(KindredTheme.accent.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Explain \"\(query)\"")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KindredTheme.text)
                            Text("Ask the AI for a step-by-step guide")
                                .font(.caption).foregroundStyle(KindredTheme.subtext)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2).foregroundStyle(KindredTheme.faint)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(matches.indices, id: \.self) { i in
                    techniqueRow(matches[i])
                    if i < matches.count - 1 { Divider().padding(.leading, 16) }
                }
            }
        }
        .background(KindredTheme.card,
                    in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous)
            .stroke(KindredTheme.hairline, lineWidth: 1))
    }

    private func categorySection(_ cat: (title: String, icon: String, tint: Color, techniques: [String])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: cat.icon).font(.caption).foregroundStyle(cat.tint)
                Text(cat.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KindredTheme.faint)
                    .tracking(0.6)
            }
            VStack(spacing: 0) {
                ForEach(cat.techniques.indices, id: \.self) { i in
                    techniqueRow(cat.techniques[i])
                    if i < cat.techniques.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(KindredTheme.card,
                        in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous)
                .stroke(KindredTheme.hairline, lineWidth: 1))
        }
    }

    private func techniqueRow(_ name: String) -> some View {
        Button {
            navigateTo = IdentifiableString(name)
        } label: {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(KindredTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(KindredTheme.faint)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Lightweight Identifiable wrapper for a plain String so it can drive
/// `.sheet(item:)` and `navigationDestination(item:)`.
struct IdentifiableString: Identifiable, Hashable {
    let id = UUID()
    let value: String
    init(_ value: String) { self.value = value }
}

#Preview {
    TechniquesView()
        .preferredColorScheme(.dark)
}
