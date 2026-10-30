import Testing
@testable import VideoDiscovery

@Test func tabsAreDistinct() {
    #expect(AppTab.discover != AppTab.favorites)
}
