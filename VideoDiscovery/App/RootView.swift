import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .discover
    // Each tab owns its navigation path here, so switching tabs never resets a stack.
    @State private var discoverPath = NavigationPath()
    @State private var favoritesPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $discoverPath) {
                DiscoverView()
            }
            .environment(\.isTabActive, selectedTab == .discover)
            .tabItem { Label("Discover", systemImage: "play.rectangle") }
            .tag(AppTab.discover)

            NavigationStack(path: $favoritesPath) {
                FavoritesView()
            }
            .environment(\.isTabActive, selectedTab == .favorites)
            .tabItem { Label("Favourites", systemImage: "heart") }
            .tag(AppTab.favorites)
        }
    }
}

#Preview {
    RootView()
}
