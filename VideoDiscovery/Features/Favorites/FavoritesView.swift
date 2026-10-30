import SwiftUI

struct FavoritesView: View {
    var body: some View {
        Text("Favourites")
            .navigationTitle("Favourites")
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
    }
}
