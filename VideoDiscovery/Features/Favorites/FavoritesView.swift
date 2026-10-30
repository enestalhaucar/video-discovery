import SwiftUI

struct FavoritesView: View {
    /// Switches to the Discover tab from the empty state.
    var onBrowse: () -> Void = {}

    @Environment(FavoritesStore.self) private var favoritesStore

    var body: some View {
        List {
            ForEach(favoritesStore.favorites) { video in
                // The link sits invisibly behind the row so the list draws no chevron.
                FavoriteRow(video: video)
                    .background {
                        NavigationLink(value: video) { EmptyView() }
                            .opacity(0)
                    }
                    .listRowInsets(EdgeInsets(
                        top: Theme.Space.pt12,
                        leading: Theme.Space.pt16,
                        bottom: Theme.Space.pt12,
                        trailing: Theme.Space.pt4
                    ))
                    .listRowBackground(Theme.surface)
                    .swipeActions(edge: .trailing) {
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            withAnimation(Motion.listChange) { favoritesStore.remove(video) }
                        }
                        .tint(Theme.destructiveFill)
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .animation(Motion.listChange, value: favoritesStore.favorites)
        .overlay {
            if favoritesStore.favorites.isEmpty {
                StateView(
                    symbol: "heart",
                    title: "No favourites yet",
                    message: "Tap the heart on any video to save it here.",
                    actionTitle: "Browse videos",
                    pulses: true,
                    action: onBrowse
                )
                .transition(.opacity)
            }
        }
        .navigationTitle("Favourites")
    }
}

private struct FavoriteRow: View {
    let video: Video

    var body: some View {
        HStack(spacing: Theme.Space.pt12) {
            ThumbnailView(url: video.thumbnailURL, cornerRadius: Theme.Radius.compact)
                .frame(width: Theme.Size.rowThumbWidth)
            VStack(alignment: .leading, spacing: Theme.Space.pt4) {
                Text(video.title)
                    .font(.headline)
                    .foregroundStyle(Theme.label)
                    .lineLimit(2)
                CategoryTag(category: video.category)
            }
            .layoutPriority(1)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            FavoriteButton(video: video)
        }
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
