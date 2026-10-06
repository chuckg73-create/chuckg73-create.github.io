import SwiftUI

/// Shared toolbar button that opens the taste-profile editor as a sheet.
/// Shows the user's profile photo when one has been set.
struct ProfileToolbarButton: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(HouseholdStore.self) private var household
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            ZStack(alignment: .bottomTrailing) {
                if let data = profileStore.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(KindredTheme.hairline, lineWidth: 1))
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                }
                if household.isSharedCook {
                    Circle()
                        .fill(KindredTheme.accent)
                        .frame(width: 9, height: 9)
                        .offset(x: 2, y: 2)
                }
            }
        }
        .accessibilityLabel("Taste profile")
        .sheet(isPresented: $show) {
            NavigationStack { TasteProfileView() }
        }
    }
}
