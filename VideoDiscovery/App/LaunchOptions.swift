#if DEBUG
import Foundation

/// Launch arguments for trying every screen state without a network or a seeded device.
///
/// - `-catalog-stub loaded|empty|error|slow` replaces the network with canned data.
/// - `-favorites none|sample` starts with no favourites or with three saved videos.
enum LaunchOptions {
    static var catalogStub: StubCatalogService.Behavior? {
        UserDefaults.standard.string(forKey: "catalog-stub").flatMap(StubCatalogService.Behavior.init)
    }

    static var initialFavorites: [Video]? {
        switch UserDefaults.standard.string(forKey: "favorites") {
        case "none":
            []
        case "sample":
            [Video.samples[1], Video.samples[5], Video.samples[0]]
        default:
            nil
        }
    }
}
#endif
