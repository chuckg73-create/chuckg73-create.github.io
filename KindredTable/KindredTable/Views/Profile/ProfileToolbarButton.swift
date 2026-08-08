import SwiftUI

/// Shared toolbar button that opens the taste-profile editor as a sheet.
struct ProfileToolbarButton: View {
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Image(systemName: "person.crop.circle")
        }
        .accessibilityLabel("Taste profile")
        .sheet(isPresented: $show) {
            NavigationStack { TasteProfileView() }
        }
    }
}
