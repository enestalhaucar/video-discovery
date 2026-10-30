import Foundation
import OSLog

protocol FavoritesPersisting {
    func load() -> [Video]
    func save(_ videos: [Video])
}

/// Stores favourites as JSON in Application Support.
///
/// It keeps a full copy of each video, so the Favourites tab still works when the catalogue
/// can't be fetched.
struct FileFavoritesPersistence: FavoritesPersisting {
    private static let logger = Logger(subsystem: "com.enestalhaucar.VideoDiscovery", category: "Favorites")

    let fileURL: URL

    init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "favorites.json")) {
        self.fileURL = fileURL
    }

    func load() -> [Video] {
        // Not percent-encoded: "Application Support" contains a space.
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Video].self, from: data)
        } catch {
            Self.logger.error("Couldn't read favourites: \(error.localizedDescription)")
            return []
        }
    }

    func save(_ videos: [Video]) {
        do {
            // iOS doesn't create Application Support inside the app container on its own.
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(videos)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Self.logger.error("Couldn't save favourites: \(error.localizedDescription)")
        }
    }
}
