import SwiftUI

struct RootView: View {
    @State private var discoverModel: DiscoverModel
    @State private var selectedTab: AppTab = .discover
    // Each tab owns its navigation path here, so switching tabs never resets a stack.
    @State private var discoverPath = NavigationPath()
    @State private var favoritesPath = NavigationPath()

    init(catalogService: CatalogServicing) {
        _discoverModel = State(initialValue: DiscoverModel(service: catalogService))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $discoverPath) {
                DiscoverView(model: discoverModel)
                    .navigationDestination(for: Video.self) { VideoDetailView(video: $0) }
            }
            .environment(\.isTabActive, selectedTab == .discover)
            .tabItem { Label("Discover", systemImage: "play.rectangle") }
            .tag(AppTab.discover)

            NavigationStack(path: $favoritesPath) {
                FavoritesView()
                    .navigationDestination(for: Video.self) { VideoDetailView(video: $0) }
            }
            .environment(\.isTabActive, selectedTab == .favorites)
            .tabItem { Label("Favourites", systemImage: "heart") }
            .tag(AppTab.favorites)
        }
        // Loaded here rather than in DiscoverView: the root never disappears, so switching tabs
        // during the first load can't cancel the request.
        .task { await discoverModel.load() }
    }
}

#Preview {
    RootView(catalogService: StubCatalogService())
        .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
