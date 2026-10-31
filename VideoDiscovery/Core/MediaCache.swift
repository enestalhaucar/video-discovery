import AVFoundation
import CryptoKit
import OSLog
import UIKit

/// Caches the app's downloads for one session only.
///
/// Thumbnails live in memory. A video's first view downloads it once: the same bytes feed the player
/// (through `CachingResourceLoader`) and end up in a temporary folder, so a replay plays from the file.
/// The folder is wiped when the cache is created, which happens once per launch: iOS gives no callback
/// when the app is force-quit, so clearing at the next launch is what guarantees that nothing outlives a
/// session.
@MainActor
final class MediaCache {
    static let shared = MediaCache()

    nonisolated private static let logger = Logger(subsystem: "com.enestalhaucar.VideoDiscovery", category: "Cache")

    private let images = NSCache<NSURL, UIImage>()
    private var imageTasks: [URL: Task<UIImage, any Error>] = [:]
    private var videoLoaders: [URL: CachingResourceLoader] = [:]
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

    /// A player item for `remote`: the saved file when there is one, otherwise a stream whose one download
    /// also becomes the saved file.
    func playerItem(for remote: URL) -> AVPlayerItem {
        let file = fileURL(for: remote)
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            Self.logger.info("Playing \(remote.lastPathComponent, privacy: .public) from session cache")
            return AVPlayerItem(url: file)
        }
        guard let assetURL = CachingResourceLoader.assetURL(for: remote) else {
            return AVPlayerItem(url: remote)
        }
        let loader = videoLoaders[remote] ?? makeLoader(for: remote, saving: file)
        let asset = AVURLAsset(url: assetURL)
        asset.resourceLoader.setDelegate(loader, queue: loader.queue)
        return AVPlayerItem(asset: asset)
    }

    /// The resource loader only holds its delegate weakly, so the cache keeps every loader alive while
    /// its assets may still ask for ranges. A finished loader stays (it's small, and the next item plays
    /// the file anyway); a failed one is dropped so a retry downloads again.
    private func makeLoader(for remote: URL, saving file: URL) -> CachingResourceLoader {
        let loader = CachingResourceLoader(remote: remote, destination: file) { [weak self] loader, succeeded in
            guard !succeeded else { return }
            Task { @MainActor in
                guard let self, self.videoLoaders[remote] === loader else { return }
                self.videoLoaders[remote] = nil
            }
        }
        videoLoaders[remote] = loader
        return loader
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
