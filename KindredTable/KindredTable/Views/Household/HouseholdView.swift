import SwiftUI

/// "Cooking together" hub: share your taste by QR/link, add family by scanning
/// theirs, and toggle who's at the table. Recipes then blend everyone's taste.
struct HouseholdView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(\.dismiss) private var dismiss

    @State private var showShare = false
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        intro
                        membersCard
                        actions
                        Label("Everything here stays on your phones. No accounts — a card is only shared when you show the code.",
                              systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(KindredTheme.faint)
                            .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Cooking together")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showShare) { ShareTasteSheet() }
            .sheet(isPresented: $showAdd) { AddMemberSheet() }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cook for everyone")
                .font(.title2).fontWeight(.bold)
            Text("Add the people at your table and Kindred Kitchen blends your tastes — combining what you all love and never suggesting anything someone dislikes or is allergic to.")
                .font(.subheadline)
                .foregroundStyle(KindredTheme.subtext)
        }
    }

    private var membersCard: some View {
        KindredCard {
            VStack(spacing: 0) {
                // You
                HStack(spacing: 12) {
                    avatar("person.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You").font(.headline)
                        TextField("Your name (for sharing)", text: Binding(
                            get: { household.myName },
                            set: { household.myName = $0 }
                        ))
                        .font(.caption)
                        .foregroundStyle(KindredTheme.subtext)
                        .textInputAutocapitalization(.words)
                    }
                    Spacer()
                    Text("Always").font(.caption).foregroundStyle(KindredTheme.faint)
                }
                .padding(.vertical, 10)

                if household.guests.isEmpty {
                    Divider().overlay(KindredTheme.hairline)
                    Text("No one else yet. Share your taste or scan a family member's code below.")
                        .font(.caption)
                        .foregroundStyle(KindredTheme.faint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                } else {
                    ForEach(household.guests) { guest in
                        Divider().overlay(KindredTheme.hairline)
                        memberRow(guest)
                    }
                }
            }
        }
    }

    private func memberRow(_ guest: TasteMember) -> some View {
        HStack(spacing: 12) {
            avatar("person.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(guest.name).font(.headline)
                Text(guest.isActive ? "At the table" : "Not cooking for")
                    .font(.caption).foregroundStyle(KindredTheme.faint)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { guest.isActive },
                set: { _ in household.toggle(guest) }
            ))
            .labelsHidden()
            .tint(KindredTheme.accent)
        }
        .padding(.vertical, 10)
        .contextMenu {
            Button(role: .destructive) { household.remove(guest) } label: {
                Label("Remove \(guest.name)", systemImage: "trash")
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            KindredButton(title: "Share my taste", systemImage: "qrcode") { showShare = true }
            Button {
                showAdd = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Add someone").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(KindredTheme.text)
                .background(KindredTheme.card, in: Capsule())
                .overlay(Capsule().stroke(KindredTheme.hairline, lineWidth: 1))
            }
        }
    }

    private func avatar(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(KindredTheme.brandGradient, in: Circle())
    }
}

// MARK: - Share my taste (QR + link)

private struct ShareTasteSheet: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        TextField("Your name", text: Binding(
                            get: { household.myName },
                            set: { household.myName = $0 }
                        ))
                        .textInputAutocapitalization(.words)
                        .multilineTextAlignment(.center)
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 14))

                        qr

                        Text("Have a family member scan this in their Kindred Kitchen, or send them the link.")
                            .font(.subheadline)
                            .foregroundStyle(KindredTheme.subtext)
                            .multilineTextAlignment(.center)

                        if let url = card.shareURL {
                            ShareLink(item: url) {
                                Label("Share link", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(KindredTheme.accent)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Share my taste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var card: TasteCard { household.myCard(profile: profileStore.profile) }

    @ViewBuilder private var qr: some View {
        if let url = card.shareURL, let image = QRCode.image(from: url.absoluteString) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 240)
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        } else {
            Text("Couldn't build a code.").foregroundStyle(KindredTheme.subtext)
        }
    }
}

// MARK: - Add someone (scan or paste)

private struct AddMemberSheet: View {
    @Environment(HouseholdStore.self) private var household
    @Environment(\.dismiss) private var dismiss

    @State private var pasted = ""
    @State private var error: String?
    @State private var addedName: String?

    var body: some View {
        NavigationStack {
            ZStack {
                KindredBackground().ignoresSafeArea()
                content
            }
            .navigationTitle("Add someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
            .alert("Added \(addedName ?? "")", isPresented: Binding(
                get: { addedName != nil }, set: { if !$0 { addedName = nil; dismiss() } }
            )) {
                Button("Done") { addedName = nil; dismiss() }
            } message: {
                Text("They're now at your table. Recipes will blend their taste with yours.")
            }
        }
    }

    @ViewBuilder private var content: some View {
        if QRScannerView.isAvailable {
            ZStack(alignment: .bottom) {
                QRScannerView { code in handle(code) }
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    Text("Point at a family member's Kindred Kitchen code")
                        .font(.subheadline).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.black.opacity(0.5), in: Capsule())
                    pasteFallback
                }
                .padding(.bottom, 30)
            }
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 44)).foregroundStyle(KindredTheme.accent)
                    Text("No camera on this device")
                        .font(.headline)
                    Text("Paste the invite link they sent you instead.")
                        .font(.subheadline).foregroundStyle(KindredTheme.subtext)
                        .multilineTextAlignment(.center)
                    pasteFallback
                }
                .padding(24)
            }
        }
    }

    private var pasteFallback: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Paste invite link", text: $pasted)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(KindredTheme.card, in: RoundedRectangle(cornerRadius: 12))
                Button("Add") { handle(pasted) }
                    .disabled(pasted.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(KindredTheme.amber)
            }
        }
        .padding(.horizontal, 24)
    }

    private func handle(_ raw: String) {
        guard let card = TasteCard.parse(raw) else {
            error = "That doesn't look like a Kindred Kitchen code."
            return
        }
        household.add(card)
        addedName = card.name
    }
}
