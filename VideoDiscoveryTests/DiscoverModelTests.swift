import Testing
@testable import VideoDiscovery

@MainActor
struct DiscoverModelTests {
    @Test func catalogueIsFetchedOnceThenRevealedAndSearchedLocally() async {
        let service = MockCatalogService()
        let model = DiscoverModel(service: service)

        await model.load()
        #expect(model.displayedVideos.map(\.id) == ["video-01", "video-02", "video-03"])

        // Search covers entries that haven't been revealed yet, and doesn't page.
        model.query = "  unavailable "
        #expect(model.displayedVideos.map(\.id) == ["video-08"])
        model.revealMore()
        model.query = ""
        #expect(model.displayedVideos.count == 3)

        // Batches of up to three come from the fetched data: 3 → 6 → 8, then stop.
        model.revealMore()
        #expect(model.displayedVideos.count == 6)
        model.revealMore()
        #expect(model.displayedVideos.count == 8)
        model.revealMore()
        #expect(model.displayedVideos.count == 8)

        await model.load()
        #expect(await service.fetchCount == 1)
    }
}
