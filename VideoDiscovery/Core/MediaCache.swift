import CryptoKit
import OSLog
import UIKit

/// Caches the app's downloads for one session only.
///
/// Thumbnails live in memory. Videos stream on their first view and are saved to a temporary folder in
/// the background, so a replay plays from the file. The folder is wiped when the cache is created, which
/// happens once per launch: iOS gives no callback when the app is force-quit, so clearing at the next
/// launch is what guarantees that nothing outlives a session.
@MainActor
final class MediaCache {
    static let shared = MediaCache()

    nonisolated private static let logger = Logger(subsystem: "com.enestalhaucar.VideoDiscovery", category: "Cache")

    private let images = NSCache<NSURL, UIImage>()
    private var imageTasks: [URL: Task<UIImage, any Error>] = [:]
    private var videoTasks: [URL: Task<Void, Never>] = [:]
    private let folder: URL

    private init() {
        let folder = FileManager.default.temporaryDirectory.appending(path: "SessionMedia", directoryHint: .isDirectory)
        self.folder = folder
        Self.resetFolder(folder)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Self.resetFolder(folder)
        }
    }

    // MARK: - Images

    /// The image if it is already in memory, so a view can show it without waiting.
    func cachedImage(for url: URL) -> UIImage? {
        images.object(forKey: url as NSURL)
    }

    /// Returns the cached image or downloads it. Concurrent calls for one URL share a single request.
    func image(for url: URL) async throws -> UIImage {
        if let image = cachedImage(for: url) {
            return image
        }
        let task: Task<UIImage, any Error>
        if let running = imageTasks[url] {
            task = running
        } else {
            // Not tied to the caller: scrolling away from a thumbnail still lets the download finish.
            task = Task {
                defer { imageTasks[url] = nil }
                let image = try await Self.downloadImage(from: url)
                images.setObject(image, forKey: url as NSURL)
                return image
            }
            imageTasks[url] = task
        }
        let image = try await task.value
        try Task.checkCancellation()
        return image
    }

    // MARK: - Videos

    /// The saved file when this video was downloaded earlier, otherwise `remote` so it streams at once.
    func playableURL(for remote: URL) -> URL {
        let file = fileURL(for: remote)
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            Self.logger.info("Playing \(remote.lastPathComponent, privacy: .public) from session cache")
            return file
        }
        return remote
    }

    /// Saves the video for a later replay, unless it's already saved or being saved.
    ///
    /// The player calls this once its stream is ready, so the copy doesn't compete with the first buffering.
    func saveForReplay(_ remote: URL) {
        let file = fileURL(for: remote)
        guard !FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return }
        saveVideo(from: remote, to: file)
    }

    private func saveVideo(from remote: URL, to file: URL) {
        guard videoTasks[remote] == nil else { return }
        videoTasks[remote] = Task {
            defer { videoTasks[remote] = nil }
            do {
                try await Self.downloadVideo(from: remote, to: file)
                Self.logger.info("Saved \(remote.lastPathComponent, privacy: .public) to session cache")
            } catch {
                // Streaming keeps working without the file.
                Self.logger.error(
                    "Couldn't cache \(remote.lastPathComponent, privacy: .public): \(error.localizedDescription)"
                )
            }
        }
    }

    /// Keyed by the absolute URL, since two catalogue entries can share one clip.
    private func fileURL(for remote: URL) -> URL {
        let name = SHA256.hash(data: Data(remote.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let file = folder.appending(path: name)
        return remote.pathExtension.isEmpty ? file : file.appendingPathExtension(remote.pathExtension)
    }

    // MARK: - Work off the main actor

    nonisolated private static func downloadImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        try requireSuccess(response)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        // Decodes now, so the first frame on screen doesn't pay for it.
        return await image.byPreparingForDisplay() ?? image
    }

    nonisolated private static func downloadVideo(from remote: URL, to file: URL) async throws {
        let (temporaryFile, response) = try await URLSession.shared.download(from: remote)
        try requireSuccess(response)
        // A move inside one volume is atomic, so a half-written file never sits at the final path.
        try? FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: temporaryFile, to: file)
    }

    /// Error pages (the catalogue has a video that answers 403 with HTML) must never be cached.
    nonisolated private static func requireSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    nonisolated private static func resetFolder(_ folder: URL) {
        do {
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            logger.error("Couldn't reset the media folder: \(error.localizedDescription)")
        }
    }
}
