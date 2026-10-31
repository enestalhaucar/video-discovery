import SwiftUI
import Testing
import UIKit
@testable import VideoDiscovery

/// Every screen state that needs no network, in light and dark. Thumbnails are left out so the placeholder
/// surface is drawn, which keeps the images deterministic.
@MainActor
@Suite(.snapshotDevice, .serialized)
struct ScreenSnapshotTests {
    nonisolated private static let styles: [UIUserInterfaceStyle] = [.light, .dark]

    // MARK: Discover

    @Test(arguments: styles)
    func discoverFeed(style: UIUserInterfaceStyle) async throws {
        let screen = DiscoverScreen(service: MockCatalogService(videos: Self.videosWithoutArtwork))
        try await Snapshot.assert(screen.environment(Self.favorites([])), named: "discover-feed", style: style)
    }

    @Test(arguments: styles)
    func discoverError(style: UIUserInterfaceStyle) async throws {
        let screen = DiscoverScreen(service: StubCatalogService(behavior: .error))
        try await Snapshot.assert(screen.environment(Self.favorites([])), named: "discover-error", style: style)
    }

    @Test(arguments: styles)
    func discoverEmpty(style: UIUserInterfaceStyle) async throws {
        let screen = DiscoverScreen(service: StubCatalogService(behavior: .empty))
        try await Snapshot.assert(screen.environment(Self.favorites([])), named: "discover-empty", style: style)
    }

    @Test(arguments: styles)
    func discoverNoResults(style: UIUserInterfaceStyle) async throws {
        let screen = DiscoverScreen(service: MockCatalogService(videos: Self.videosWithoutArtwork), query: "ocean")
        try await Snapshot.assert(screen.environment(Self.favorites([])), named: "discover-no-results", style: style)
    }

    // MARK: Favourites

    @Test(arguments: styles)
    func favouritesList(style: UIUserInterfaceStyle) async throws {
        let videos = Self.videosWithoutArtwork
        let screen = NavigationStack { FavoritesView() }
            .environment(Self.favorites([videos[1], videos[5], videos[0]]))
        try await Snapshot.assert(screen, named: "favourites-list", style: style)
    }

    @Test(arguments: styles)
    func favouritesEmpty(style: UIUserInterfaceStyle) async throws {
        let screen = NavigationStack { FavoritesView() }
            .environment(Self.favorites([]))
        try await Snapshot.assert(screen, named: "favourites-empty", style: style)
    }

    // MARK: Helpers

    static let videosWithoutArtwork = Video.samples.map {
        Video(
            id: $0.id,
            title: $0.title,
            category: $0.category,
            description: $0.description,
            videoURL: $0.videoURL,
            thumbnailURL: nil
        )
    }

    /// A store backed by its own file, so the app's real favourites are never touched.
    static func favorites(_ videos: [Video]) -> FavoritesStore {
        let persistence = FileFavoritesPersistence(
            fileURL: .temporaryDirectory.appending(path: "snapshot-favorites-\(UUID().uuidString).json")
        )
        persistence.save(videos)
        let store = FavoritesStore(persistence: persistence)
        try? FileManager.default.removeItem(at: persistence.fileURL)
        return store
    }
}

/// The Discover tab as the app shows it, loading from `service` once it appears.
private struct DiscoverScreen: View {
    @State private var model: DiscoverModel
    @Namespace private var namespace

    init(service: CatalogServicing, query: String = "") {
        let model = DiscoverModel(service: service)
        model.query = query
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            DiscoverView(model: model, zoomNamespace: namespace)
        }
        .task { await model.load() }
    }
}
