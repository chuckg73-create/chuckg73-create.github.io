import SwiftUI

/// Swap one ingredient for something else (or remove it), with the change
/// rippled through the steps. Suggestions honor the cook's diets/dislikes.
struct SubstituteSheet: View {
    let recipe: Recipe
    let ingredient: RecipeIngredient
    let profile: TasteProfile
    var onApply: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    private let service = GeminiRecipeService()

    @State private var reason = ""
    @State private var options: [SubstitutionOption] = []
    @State private var isSuggesting = false
    @State private var applying: String?      // name being applied, or "remove"
    @State private var error: String?

    private let reasons = ["Make it vegetarian", "Allergy", "Don't have it", "Don't like it"]

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        reasonPicker
                        if let error { errorRow(error) }
                        suggestButton
                        if !options.isEmpty { optionsList }
                        removeRow
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Swap ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Swapping").font(.caption).foregroundStyle(KindredTheme.faint)
            Text(ingredient.display)
                .font(.title3).fontWeight(.bold).foregroundStyle(KindredTheme.text)
            Text("in \(recipe.title)").font(.subheadline).foregroundStyle(KindredTheme.subtext)
        }
    }

    private var reasonPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHY?").font(.caption2.weight(.semibold)).foregroundStyle(KindredTheme.faint).tracking(0.5)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8, alignment: .leading)],
                      alignment: .leading, spacing: 8) {
                ForEach(reasons, id: \.self) { r in
                    let on = reason == r
                    Button { reason = on ? "" : r; options = []; error = nil } label: {
                        Text(r).font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .foregroundStyle(on ? Color.white : KindredTheme.subtext)
                            .background(on ? AnyShapeStyle(KindredTheme.brandGradient) : AnyShapeStyle(KindredTheme.card), in: Capsule())
                            .overlay(Capsule().stroke(on ? Color.clear : KindredTheme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Suggestions already respect your household's diets and dislikes.")
                .font(.caption2).foregroundStyle(KindredTheme.faint)
        }
    }

    private var suggestButton: some View {
        Button { suggest() } label: {
            HStack(spacing: 8) {
                if isSuggesting { ProgressView().controlSize(.small).tint(.white); Text("Finding swaps…") }
                else { Image(systemName: "wand.and.stars"); Text(options.isEmpty ? "Suggest swaps" : "Suggest more") }
            }
            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 13)
            .foregroundStyle(.white)
            .background(KindredTheme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain).disabled(isSuggesting || applying != nil)
    }

    private var optionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TAP ONE TO SWAP").font(.caption2.weight(.semibold)).foregroundStyle(KindredTheme.faint).tracking(0.5)
            ForEach(options) { opt in
                Button { apply(opt) } label: { optionCard(opt) }
                    .buttonStyle(.plain).disabled(applying != nil)
            }
        }
    }

    private func optionCard(_ opt: SubstitutionOption) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(opt.display).font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.text)
                if !opt.note.isEmpty { Text(opt.note).font(.caption).foregroundStyle(KindredTheme.subtext) }
            }
            Spacer(minLength: 0)
            if applying == opt.name { ProgressView().controlSize(.small) }
            else { Image(systemName: "arrow.left.arrow.right").foregroundStyle(KindredTheme.accent) }
        }
        .padding(14)
        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KindredTheme.hairline, lineWidth: 1))
    }

    private var removeRow: some View {
        Button { apply(nil) } label: {
            HStack(spacing: 8) {
                if applying == "remove" { ProgressView().controlSize(.small) }
                else { Image(systemName: "minus.circle") }
                Text("Remove it entirely")
            }
            .font(.subheadline.weight(.medium)).foregroundStyle(KindredTheme.coral)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(KindredTheme.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain).disabled(applying != nil)
    }

    private func errorRow(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.caption).foregroundStyle(KindredTheme.amber)
    }

    // MARK: Actions

    private func suggest() {
        error = nil; isSuggesting = true
        Task {
            do {
                let opts = try await service.suggestSubstitutions(for: ingredient, in: recipe, reason: reason, profile: profile)
                await MainActor.run { options = opts; isSuggesting = false; if opts.isEmpty { error = "No good swaps came back — try a different reason." } }
            } catch {
                await MainActor.run { isSuggesting = false; self.error = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription }
            }
        }
    }

    private func apply(_ opt: SubstitutionOption?) {
        error = nil; applying = opt?.name ?? "remove"
        Task {
            do {
                let updated = try await service.applySubstitution(in: recipe, replacing: ingredient, with: opt, reason: reason, profile: profile)
                await MainActor.run { applying = nil; onApply(updated); dismiss() }
            } catch {
                await MainActor.run { applying = nil; self.error = (error as? RecipeServiceError)?.errorDescription ?? error.localizedDescription }
            }
        }
    }
}
