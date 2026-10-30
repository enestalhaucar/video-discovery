import SwiftUI

struct RootView: View {
    let catalogService: CatalogServicing

    @State private var selectedTab: AppTab = .discover
    // Each tab owns its navigation path here, so switching tabs never resets a stack.
    @State private var discoverPath = NavigationPath()
    @State private var favoritesPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $discoverPath) {
                DiscoverView()
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
    }
}

#Preview {
    RootView(catalogService: StubCatalogService())
        .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
