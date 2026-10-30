import SwiftUI

// Placeholder until the designed Favourites list lands.
struct FavoritesView: View {
    @Environment(FavoritesStore.self) private var favoritesStore

    var body: some View {
        List(favoritesStore.favorites) { video in
            NavigationLink(video.title, value: video)
        }
        .navigationTitle("Favourites")
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
