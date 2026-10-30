import Foundation

struct Video: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let category: String
    let description: String
    let videoURL: URL
    let thumbnailURL: URL?
}

/// The catalogue endpoint wraps the list in a `videos` key.
struct CatalogResponse: Decodable {
    let videos: [Video]
}
