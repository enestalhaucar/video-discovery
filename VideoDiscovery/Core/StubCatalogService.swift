import Foundation

/// Canned catalogue for SwiftUI previews and the DEBUG launch arguments.
struct StubCatalogService: CatalogServicing {
    enum Behavior: String, Sendable {
        case loaded
        case empty
        case error
        case slow
    }

    var behavior: Behavior = .loaded

    func fetchCatalog() async throws -> [Video] {
        switch behavior {
        case .loaded:
            return Video.samples
        case .empty:
            return []
        case .error:
            throw CatalogError.offline
        case .slow:
            try await Task.sleep(for: .seconds(4))
            return Video.samples
        }
    }
}

extension Video {
    /// A copy of the live catalogue, used by previews, the stub service and tests.
    static let samples: [Video] = [
        Video(
            id: "video-01",
            title: "Big Buck Bunny",
            category: "Animation",
            description: "A short animated sample featuring Big Buck Bunny.",
            videoURL: sampleURL("https://www.w3schools.com/tags/mov_bbb.mp4"),
            thumbnailURL: nil
        ),
        Video(
            id: "video-02",
            title: "City Road",
            category: "City",
            description: "A short view of a road in the city.",
            videoURL: sampleURL("https://samplelib.com/mp4/sample-5s.mp4"),
            thumbnailURL: sampleURL("https://samplelib.com/preview/mp4/sample-5s.jpg")
        ),
        Video(
            id: "video-03",
            title: "Buses by the Park",
            category: "City",
            description: "Buses passing beside a park.",
            videoURL: sampleURL("https://samplelib.com/mp4/sample-10s.mp4"),
            thumbnailURL: sampleURL("https://samplelib.com/preview/mp4/sample-10s.jpg")
        ),
        Video(
            id: "video-04",
            title: "Passing Traffic",
            category: "City",
            description: "A stream of vehicles passing by a park.",
            videoURL: sampleURL("https://samplelib.com/mp4/sample-15s.mp4"),
            thumbnailURL: sampleURL("https://samplelib.com/preview/mp4/sample-15s.jpg")
        ),
        Video(
            id: "video-05",
            title: "Road and Traffic",
            category: "Travel",
            description: "A longer view of the road and traffic flow.",
            videoURL: sampleURL("https://samplelib.com/mp4/sample-20s-720p.mp4"),
            thumbnailURL: sampleURL("https://samplelib.com/preview/mp4/sample-20s.jpg")
        ),
        Video(
            id: "video-06",
            title: "Around the Park",
            category: "Travel",
            description: "Roads, park scenery, and pedestrians.",
            videoURL: sampleURL("https://samplelib.com/mp4/sample-30s-360p.mp4"),
            thumbnailURL: sampleURL("https://samplelib.com/preview/mp4/sample-30s.jpg")
        ),
        Video(
            id: "video-07",
            title: "City Road: Another Look",
            category: "Highlights",
            description: "Another catalogue entry featuring the City Road clip.",
            videoURL: sampleURL("https://samplelib.com/mp4/sample-5s.mp4"),
            thumbnailURL: sampleURL("https://samplelib.com/preview/mp4/sample-5s.jpg")
        ),
        Video(
            id: "video-08",
            title: "Unavailable Preview",
            category: "Highlights",
            description: "A sample entry whose video is intentionally unavailable.",
            videoURL: sampleURL("https://samplelib.com/mp4/ios-case-unavailable.mp4"),
            thumbnailURL: sampleURL("https://samplelib.com/preview/mp4/sample-10s.jpg")
        )
    ]

    private static func sampleURL(_ string: String) -> URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: string)!
    }
}
