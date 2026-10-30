import AVFoundation
import OSLog
import SwiftUI

@main
struct VideoDiscoveryApp: App {
    @State private var favoritesStore = FavoritesStore(persistence: FileFavoritesPersistence())
    private let catalogService: CatalogServicing = RemoteCatalogService()

    init() {
        Self.configureAudioSession()
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
