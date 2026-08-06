import Foundation
import Observation

/// One person you're cooking for (a guest added by QR/link). "You" is the
/// ProfileStore profile and is not stored here.
struct TasteMember: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var profile: TasteProfile
    var isActive: Bool = true
}

/// The local "cooking for" group — your name plus the guests you've added by
/// QR/link. No accounts, on-device only (same stance as [[LocalStore]]).
@Observable
final class HouseholdStore {

    var myName: String { didSet { persist() } }
    var guests: [TasteMember] { didSet { persist() } }

    private let fileName = "household.json"

    private struct Snapshot: Codable {
        var myName: String
        var guests: [TasteMember]
    }

    init(seedGuests: [TasteMember] = []) {
        let snapshot = LocalStore.load(Snapshot.self, from: fileName)
        myName = snapshot?.myName ?? "Me"
        guests = snapshot?.guests ?? seedGuests
    }

    var activeGuests: [TasteMember] { guests.filter(\.isActive) }

    /// True when more than one person is being cooked for.
    var isSharedCook: Bool { !activeGuests.isEmpty }

    /// Add (or refresh) a guest from a scanned/opened card. De-dupes by name so
    /// re-scanning updates rather than duplicating.
    func add(_ card: TasteCard) {
        let name = card.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let idx = guests.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            guests[idx].profile = card.profile
            guests[idx].isActive = true
        } else {
            guests.append(TasteMember(name: name, profile: card.profile))
        }
    }

    func remove(_ member: TasteMember) {
        guests.removeAll { $0.id == member.id }
    }

    func toggle(_ member: TasteMember) {
        guard let i = guests.firstIndex(where: { $0.id == member.id }) else { return }
        guests[i].isActive.toggle()
    }

    /// The blended profile Gemini should cook for: you + every active guest.
    func effectiveProfile(you: TasteProfile) -> TasteProfile {
        TasteProfile.blend([you] + activeGuests.map(\.profile))
    }

    /// Short "You + Leslie (+1)" summary for the recipe header.
    func cookingForSummary() -> String {
        let names = ["You"] + activeGuests.map(\.name)
        switch names.count {
        case 1: return "You"
        case 2: return "\(names[0]) + \(names[1])"
        default: return "\(names[0]) + \(names[1]) +\(names.count - 2)"
        }
    }

    /// Changes whenever the active membership or any active profile changes, so
    /// the recipe feed can re-request when the group changes.
    func signature(you: TasteProfile) -> Int {
        var hasher = Hasher()
        hasher.combine(you)
        for guest in activeGuests {
            hasher.combine(guest.id)
            hasher.combine(guest.profile)
        }
        return hasher.finalize()
    }

    /// Your own shareable card.
    func myCard(profile: TasteProfile) -> TasteCard {
        TasteCard(name: myName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Me" : myName,
                  profile: profile)
    }

    private func persist() {
        LocalStore.save(Snapshot(myName: myName, guests: guests), to: fileName)
    }
}
