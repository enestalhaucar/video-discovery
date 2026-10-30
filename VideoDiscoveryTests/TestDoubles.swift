@testable import VideoDiscovery

/// Returns a fixed catalogue and counts how many requests were made.
actor MockCatalogService: CatalogServicing {
    private(set) var fetchCount = 0
    private let videos: [Video]

    init(videos: [Video] = Video.samples) {
        self.videos = videos
    }

    func fetchCatalog() async throws -> [Video] {
        fetchCount += 1
        return videos
    }
}
