import SwiftUI

struct WhatsNewView: View {
    private let features: [(icon: String, tint: Color, title: String, detail: String)] = [
        ("link.circle.fill", KindredTheme.accent,
         "Import any recipe from the web",
         "Paste a URL from NYT Cooking, Serious Eats, AllRecipes, or anywhere -- Gemini extracts it straight into your cookbook."),
        ("timer.circle.fill", KindredTheme.mint,
         "Multiple timers at once",
         "Name each timer (wings, sauce, rice), run them all at once, and pause or dismiss individually in Cook Mode."),
        ("camera.circle.fill", KindredTheme.coral,
         "Finished dish photos",
         "Snap a photo right after you rate a cooked recipe. Saved to your cookbook so you remember how it turned out."),
        ("wand.and.stars", KindredTheme.amber,
         "In-cook substitutions",
         "Missing something mid-recipe? Tap Substitute and get an AI swap suggestion without leaving Cook Mode."),
        ("bubble.left.and.text.bubble.right.fill", KindredTheme.blue,
         "Chef AI front and center",
         "The search bar is now inline on the home screen -- type your idea and go straight to recipes, no extra taps."),
        ("figure.2.and.child.holdinghands", KindredTheme.accent,
         "Cook for the whole family",
         "Add family members by QR code and KindredTable blends everyone's taste -- never suggesting something someone dislikes or is allergic to."),
    ]

    var body: some View {
        ZStack {
            KindredBackground()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Version 3.4")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KindredTheme.accent)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(KindredTheme.accent.opacity(0.12), in: Capsule())
                        Text("What's New")
                            .font(.title2).fontWeight(.bold).foregroundStyle(KindredTheme.text)
                        Text("Six new features to make cooking easier for everyone at your table.")
                            .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 0) {
                        ForEach(features.indices, id: \.self) { i in
                            let f = features[i]
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: f.icon)
                                    .font(.title3).foregroundStyle(f.tint)
                                    .frame(width: 38, height: 38)
                                    .background(f.tint.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(KindredTheme.text)
                                    Text(f.detail)
                                        .font(.caption)
                                        .foregroundStyle(KindredTheme.subtext)
                                }
                                Spacer()
                            }
                            .padding(14)
                            if i < features.count - 1 {
                                Divider().padding(.leading, 66)
                            }
                        }
                    }
                    .background(KindredTheme.card,
                                in: RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: KindredTheme.cardCorner, style: .continuous)
                            .stroke(KindredTheme.hairline, lineWidth: 1)
                    )
                }
                .padding(20)
            }
        }
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { WhatsNewView() }
        .preferredColorScheme(.dark)
}
