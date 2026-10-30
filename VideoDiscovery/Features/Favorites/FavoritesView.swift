import SwiftUI

struct FavoritesView: View {
    /// Switches to the Discover tab from the empty state.
    var onBrowse: () -> Void = {}

    @Environment(FavoritesStore.self) private var favoritesStore
    @State private var emptyHeartPulse = 0

    var body: some View {
        List {
            ForEach(favoritesStore.favorites) { video in
                NavigationLink(value: video) {
                    FavoriteRow(video: video)
                }
                .swipeActions(edge: .trailing) {
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        withAnimation(Motion.listChange) { favoritesStore.remove(video) }
                    }
                }
            }
        }
        .animation(Motion.listChange, value: favoritesStore.favorites)
        .overlay {
            if favoritesStore.favorites.isEmpty {
                emptyState
                    .transition(.opacity)
            }
        }
        .navigationTitle("Favourites")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No favourites yet")
            } icon: {
                Image(systemName: "heart")
                    .symbolEffect(.bounce, value: emptyHeartPulse)
            }
        } description: {
            Text("Tap the heart on any video to save it here.")
        } actions: {
            Button("Browse videos", action: onBrowse)
                .buttonStyle(.bordered)
        }
        .onAppear { emptyHeartPulse += 1 }
    }
}

private struct FavoriteRow: View {
    let video: Video

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(url: video.thumbnailURL, cornerRadius: 10)
                .frame(width: 100)
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                CategoryTag(category: video.category)
            }
            .layoutPriority(1)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            FavoriteButton(video: video)
        }
        .padding(.vertical, 4)
    }
}

#Preview("Saved") {
    let persistence = FileFavoritesPersistence(
        fileURL: .temporaryDirectory.appending(path: "preview-favorites.json")
    )
    persistence.save([Video.samples[1], Video.samples[5], Video.samples[0]])
    return NavigationStack {
        FavoritesView()
    }
    .environment(FavoritesStore(persistence: persistence))
}

#Preview("Empty") {
    NavigationStack {
        FavoritesView()
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence(
        fileURL: .temporaryDirectory.appending(path: "preview-empty.json")
    )))
}
