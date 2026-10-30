import AVFoundation
import OSLog
import SwiftUI

@main
struct VideoDiscoveryApp: App {
    @State private var favoritesStore: FavoritesStore
    private let catalogService: CatalogServicing

    init() {
        Self.configureAudioSession()
        let persistence = FileFavoritesPersistence()
        var catalogService: CatalogServicing = RemoteCatalogService()
        #if DEBUG
        if let favorites = LaunchOptions.initialFavorites {
            persistence.save(favorites)
        }
        if let behavior = LaunchOptions.catalogStub {
            catalogService = StubCatalogService(behavior: behavior)
        }
        #endif
        self.catalogService = catalogService
        _favoritesStore = State(initialValue: FavoritesStore(persistence: persistence))
    }

    var body: some Scene {
        WindowGroup {
            RootView(catalogService: catalogService)
                .environment(favoritesStore)
        }
    }

    /// Plays video sound even when the ring/silent switch is on silent.
    private static func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            Logger(subsystem: "com.enestalhaucar.VideoDiscovery", category: "App")
                .error("Couldn't configure the audio session: \(error.localizedDescription)")
        }
    }
}
