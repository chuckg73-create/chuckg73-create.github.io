import SwiftUI

struct TechniqueDetailView: View {
    let query: String

    @State private var guide: TechniqueGuide?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = GeminiRecipeService()

    var body: some View {
        ZStack {
            KindredBackground()
            if isLoading {
                loadingView
            } else if let guide {
                guideView(guide)
            } else if let errorMessage {
                errorView(errorMessage)
            }
        }
        .navigationTitle(guide?.title ?? query.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(KindredTheme.accent)
            Text("Looking that up...")
                .font(.subheadline)
                .foregroundStyle(KindredTheme.subtext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle).foregroundStyle(KindredTheme.amber)
            Text(msg)
                .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await load() } }
                .buttonStyle(.borderedProminent).tint(KindredTheme.accent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func guideView(_ g: TechniqueGuide) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        difficultyChip(g.difficulty)
                        Label(g.timeEstimate, systemImage: "clock")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(KindredTheme.faint)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(KindredTheme.card, in: Capsule())
                    }
                    Text(g.intro)
                        .font(.subheadline)
                        .foregroundStyle(KindredTheme.subtext)
                }

                // Steps
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Steps", icon: "list.number")
                        .padding(.bottom, 2)
                    ForEach(g.steps.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(i + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(KindredTheme.accent)
                                .frame(width: 24, height: 24)
                                .background(KindredTheme.accent.opacity(0.12),
                                            in: Circle())
                            Text(g.steps[i])
                                .font(.subheadline)
                                .foregroundStyle(KindredTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(14)
                        if i < g.steps.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(KindredTheme.card,
                            in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous)
                    .stroke(KindredTheme.hairline, lineWidth: 1))

                // Tips
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Pro tips", icon: "lightbulb.fill")
                        .padding(.bottom, 2)
                    ForEach(g.tips.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption).foregroundStyle(KindredTheme.amber)
                                .frame(width: 20)
                            Text(g.tips[i])
                                .font(.subheadline)
                                .foregroundStyle(KindredTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(14)
                        if i < g.tips.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(KindredTheme.card,
                            in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous)
                    .stroke(KindredTheme.amber.opacity(0.25), lineWidth: 1))

                // Watch video
                watchButton(query: g.youtubeQuery)
            }
            .padding(20)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundStyle(KindredTheme.accent)
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(KindredTheme.faint)
                .tracking(0.6)
        }
    }

    private func difficultyChip(_ level: String) -> some View {
        let (color, icon): (Color, String) = switch level.lowercased() {
        case "beginner":     (KindredTheme.mint, "tortoise.fill")
        case "intermediate": (KindredTheme.amber, "figure.walk")
        default:             (KindredTheme.coral, "flame.fill")
        }
        return Label(level.capitalized, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func watchButton(query: String) -> some View {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)")!
        return Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .font(.title3).foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Watch a video tutorial")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KindredTheme.text)
                    Text("Opens YouTube in Safari")
                        .font(.caption).foregroundStyle(KindredTheme.subtext)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption).foregroundStyle(KindredTheme.faint)
            }
            .padding(16)
            .background(KindredTheme.card,
                        in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous)
                .stroke(KindredTheme.hairline, lineWidth: 1))
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            guide = try await service.technique(name: query)
        } catch {
            errorMessage = "Couldn't load that technique. Check your connection and try again."
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        TechniqueDetailView(query: "soft boil an egg")
    }
    .preferredColorScheme(.dark)
}
