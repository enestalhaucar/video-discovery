import Foundation
import Testing
@testable import VideoDiscovery

@MainActor
struct FavoritesStoreTests {
    @Test func favouritesSurviveARelaunch() {
        // A folder that doesn't exist yet and has a space in its name, like Application Support
        // on a fresh install.
        let folder = FileManager.default.temporaryDirectory.appending(path: "Fresh Install \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let persistence = FileFavoritesPersistence(fileURL: folder.appending(path: "favorites.json"))
        let bunny = Video.samples[0]
        let cityRoad = Video.samples[1]

        let store = FavoritesStore(persistence: persistence)
        store.toggle(bunny)
        store.toggle(cityRoad)
        store.toggle(bunny)

        let relaunched = FavoritesStore(persistence: persistence)
        #expect(relaunched.favorites == [cityRoad])
        #expect(relaunched.isFavorite(cityRoad))
        #expect(!relaunched.isFavorite(bunny))
    }
}
