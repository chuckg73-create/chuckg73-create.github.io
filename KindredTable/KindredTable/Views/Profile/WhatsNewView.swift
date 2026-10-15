import SwiftUI

struct WhatsNewView: View {
    private let features: [(icon: String, tint: Color, title: String, detail: String)] = [
        ("lock.display", KindredTheme.accent,
         "Live on your Lock Screen",
         "Cook Mode pins your current step and any running timer to the Dynamic Island and Lock Screen so you never lose your place."),
        ("link.circle.fill", KindredTheme.blue,
         "Import any recipe from the web",
         "Paste a URL from NYT Cooking, Serious Eats, AllRecipes, or anywhere — Gemini extracts it straight into your cookbook."),
        ("book.pages.fill", KindredTheme.mint,
         "Technique guides",
         "36 built-in guides — how to fillet fish, soft-boil eggs, make a roux, deglaze a pan, and more. Each one links to a curated video tutorial."),
        ("timer.circle.fill", KindredTheme.amber,
         "Multiple timers at once",
         "Name each timer (wings, sauce, rice), run them all simultaneously, and dismiss individually without leaving Cook Mode."),
        ("percent", KindredTheme.coral,
         "Baker's percentages",
         "Scaling a baking recipe now shows every ingredient as a percentage of flour — so your ratios stay right no matter what batch size you choose."),
        ("timeline.selection", KindredTheme.accent,
         "Visual cook timeline",
         "Cook Plan now shows a Gantt-style timeline with a live Now marker, so back-timing dinner is a glance, not a calculation."),
        ("camera.circle.fill", KindredTheme.coral,
         "Finished dish photos",
         "Snap a photo right after you rate a cooked recipe. Saved to your cookbook so you remember exactly how it turned out."),
        ("wand.and.stars", KindredTheme.amber,
         "In-cook substitutions",
         "Missing something mid-recipe? Tap Substitute and get an AI swap suggestion without leaving Cook Mode."),
        ("figure.2.and.child.holdinghands", KindredTheme.blue,
         "Cook for the whole family",
         "Add family members by QR code and KindredTable blends everyone's taste — never suggesting something someone dislikes or is allergic to."),
        ("person.crop.circle.fill", KindredTheme.mint,
         "Your profile, your face",
         "Add your name and a profile photo. The toolbar icon updates to show it."),
        ("bubble.left.and.text.bubble.right.fill", KindredTheme.accent,
         "Chef AI front and center",
         "The craving search bar is now inline on the home screen — type your idea and go straight to recipes, no extra taps."),
        ("fork.knife.circle.fill", KindredTheme.coral,
         "Recreate any dish from a photo",
         "Photograph a dish at a restaurant, a friend's table, or anywhere — KindredTable identifies it and writes you a full recipe to make it at home."),
        ("circle.lefthalf.filled.righthalf.stripe.vertical.fill", KindredTheme.subtext,
         "Light mode",
         "KindredTable now follows your phone's display setting. Switch between light and dark in Settings — the app updates instantly."),
        ("sparkles", KindredTheme.accent,
         "Sharper AI, better photos",
         "Upgraded to Gemini 3.6 for recipe generation and a new dedicated image model for richer food photography."),
    ]

    var body: some View {
        ZStack {
            KindredBackground()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Version 3.6")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KindredTheme.accent)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(KindredTheme.accent.opacity(0.12), in: Capsule())
                        Text("What's New")
                            .font(.title2).fontWeight(.bold).foregroundStyle(KindredTheme.text)
                        Text("Everything your kitchen needed — Live Activities, technique guides, baker's ratios, and more.")
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
