import Foundation
import Observation

/// The single source of truth for favourites, shared by both tabs through the environment.
@MainActor
@Observable
final class FavoritesStore {
    /// Saved videos, most recently added first.
    private(set) var favorites: [Video]

    @ObservationIgnored private let persistence: FavoritesPersisting

    init(persistence: FavoritesPersisting) {
        self.persistence = persistence
        favorites = persistence.load()
    }

    func isFavorite(_ video: Video) -> Bool {
        favorites.contains { $0.id == video.id }
    }

    func toggle(_ video: Video) {
        if isFavorite(video) {
            remove(video)
        } else {
            favorites.insert(video, at: 0)
            persistence.save(favorites)
        }
    }

    func remove(_ video: Video) {
        favorites.removeAll { $0.id == video.id }
        persistence.save(favorites)
    }
}
