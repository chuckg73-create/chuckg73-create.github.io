import SwiftUI
import UIKit

/// Opens a whole exported cookbook (`.kindredcookbook`) — from a tapped file
/// or a `.fileImporter` pick — and lets the cook browse everything in it and
/// choose what to bring into their own cookbook. Everything starts selected:
/// this exists for handing down a collection nobody wants to risk losing a
/// piece of, so the easy path is "take it all."
struct CookbookPackageImportView: View {
    @Environment(SavedRecipeStore.self) private var cookbook
    @Environment(\.dismiss) private var dismiss

    let fileURL: URL

    private enum Phase {
        case loading
        case browsing(CookbookPackage)
        case failed(String)
        case done(Int)
    }

    @State private var phase: Phase = .loading
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .loading: loadingState
                        case .browsing(let package): browsingState(package)
                        case .failed(let message): failedState(message)
                        case .done(let count): doneState(count)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Import Cookbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .task { load() }
        }
    }

    // MARK: States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(KindredTheme.accent)
            Text("Opening cookbook…").font(.subheadline).foregroundStyle(KindredTheme.subtext)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 80)
    }

    private func browsingState(_ package: CookbookPackage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header(package)

            HStack {
                Text("Choose what to bring in")
                    .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.faint)
                Spacer()
                selectAllButton(package)
            }

            VStack(spacing: 10) {
                ForEach(package.recipes) { recipe in
                    row(for: recipe, package: package)
                }
            }

            KindredButton(
                title: "Import \(selected.count) recipe\(selected.count == 1 ? "" : "s")",
                systemImage: "tray.and.arrow.down.fill"
            ) {
                importSelected(package)
            }
            .disabled(selected.isEmpty)
            .opacity(selected.isEmpty ? 0.5 : 1)
        }
    }

    private func failedState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundStyle(KindredTheme.amber)
            Text("Couldn't open that file").font(.headline).foregroundStyle(KindredTheme.text)
            Text(message)
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private func doneState(_ count: Int) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48)).foregroundStyle(KindredTheme.mint)
            Text(count == 0 ? "Nothing new to add" : "Added \(count) recipe\(count == 1 ? "" : "s")")
                .font(.title3).fontWeight(.bold).foregroundStyle(KindredTheme.text)
            Text(count == 0
                 ? "Everything you picked was already in your cookbook."
                 : "They're in your Cookbook tab now, photos and all.")
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
            KindredButton(title: "Done") { dismiss() }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    // MARK: Pieces

    private func header(_ package: CookbookPackage) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 40)).foregroundStyle(KindredTheme.accent)
            Text(package.cookbookName.trimmingCharacters(in: .whitespaces).isEmpty
                 ? "A Cookbook" : package.cookbookName)
                .font(.title2).fontWeight(.bold).foregroundStyle(KindredTheme.text)
                .multilineTextAlignment(.center)
            Text("\(package.recipes.count) recipe\(package.recipes.count == 1 ? "" : "s") · exported \(package.exportedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption).foregroundStyle(KindredTheme.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func selectAllButton(_ package: CookbookPackage) -> some View {
        let allSelected = selected.count == package.recipes.count
        return Button(allSelected ? "Deselect All" : "Select All") {
            selected = allSelected ? [] : Set(package.recipes.map(\.id))
        }
        .font(.caption.weight(.semibold)).foregroundStyle(KindredTheme.accent)
    }

    private func row(for recipe: Recipe, package: CookbookPackage) -> some View {
        let alreadyHave = cookbook.saved.contains { $0.id == recipe.id }
        let isSelected = selected.contains(recipe.id)
        return Button { toggle(recipe.id) } label: {
            HStack(spacing: 12) {
                thumbnail(for: recipe, photos: package.photos)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(KindredTheme.text)
                        .lineLimit(1)
                    if !recipe.attribution.isEmpty {
                        Text(recipe.attribution).font(.caption).foregroundStyle(KindredTheme.coral).lineLimit(1)
                    } else if !recipe.summary.isEmpty {
                        Text(recipe.summary).font(.caption).foregroundStyle(KindredTheme.subtext).lineLimit(1)
                    }
                    if alreadyHave {
                        Label("Already in your cookbook", systemImage: "checkmark.circle.fill")
                            .font(.caption2).foregroundStyle(KindredTheme.faint)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? KindredTheme.accent : KindredTheme.faint)
            }
            .padding(12)
            .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KindredTheme.hairline, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func thumbnail(for recipe: Recipe, photos: [String: Data]) -> some View {
        if let data = photos[recipe.id.uuidString], let image = UIImage(data: data) {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(colors: [KindredTheme.amber, KindredTheme.coral],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(
                    Image(systemName: recipe.mealType.systemImage)
                        .font(.headline).foregroundStyle(.white.opacity(0.35))
                )
        }
    }

    // MARK: Actions

    private func load() {
        do {
            let package = try CookbookPackageService.load(from: fileURL)
            selected = Set(package.recipes.map(\.id))
            phase = .browsing(package)
        } catch {
            phase = .failed("This doesn't look like a KindredTable cookbook file, or it may be damaged.")
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func importSelected(_ package: CookbookPackage) {
        var added = 0
        for recipe in package.recipes where selected.contains(recipe.id) {
            if let data = package.photos[recipe.id.uuidString], let image = UIImage(data: data) {
                RecipeUserPhotoStore.shared.save(image, for: recipe.id)
            }
            let before = cookbook.saved.count
            cookbook.add(recipe)
            if cookbook.saved.count > before { added += 1 }
        }
        phase = .done(added)
    }
}

#Preview {
    CookbookPackageImportView(fileURL: URL(fileURLWithPath: "/dev/null"))
        .environment(SavedRecipeStore())
        .preferredColorScheme(.dark)
}
