import AVFoundation
import OSLog
import UniformTypeIdentifiers

/// Feeds a player from one download of the whole file and keeps that download as the session copy.
///
/// The player asks for byte ranges through `AVAssetResourceLoader`. They are answered from a single
/// sequential `URLSession` data task whose bytes go to a partial file; a range that hasn't arrived yet
/// waits for it. When a 2xx transfer completes, the partial file is moved to `destination`, so the next
/// view plays the local file. An error response (the catalogue has a video that answers 403 with HTML)
/// or a failed transfer fails every pending request, so the player fails as it would on its own, and
/// nothing is saved.
///
/// One loader can serve several assets for the same URL, so reopening a video mid-download shares it.
///
/// Thread safety: every mutable property is read and written only on `queue`. That serial queue runs the
/// resource loader callbacks (`setDelegate(_:queue:)`) and, as the session's delegate queue, the
/// URLSession callbacks, which is what makes the `@unchecked Sendable` sound.
final class CachingResourceLoader: NSObject, AVAssetResourceLoaderDelegate, URLSessionDataDelegate,
    @unchecked Sendable {
    /// Prefixed to the remote scheme, so AVFoundation hands every request to the delegate.
    static let schemePrefix = "vdcache-"

    let queue = DispatchQueue(label: "com.enestalhaucar.VideoDiscovery.CachingResourceLoader")

    private static let logger = Logger(subsystem: "com.enestalhaucar.VideoDiscovery", category: "Cache")
    /// Keeps a single `respond(with:)` call from reading a whole large range into memory.
    private static let chunkSize: Int64 = 512 * 1024

    private let remote: URL
    private let destination: URL
    private let partial: URL
    private let configuration: URLSessionConfiguration
    private let onFinish: @Sendable (CachingResourceLoader, _ succeeded: Bool) -> Void

    // Confined to `queue`.
    private var hasStarted = false
    private var pending: [AVAssetResourceLoadingRequest] = []
    private var response: HTTPURLResponse?
    private var writer: FileHandle?
    private var reader: FileHandle?
    private var received: Int64 = 0
    private var isComplete = false
    private var failure: (any Error)?

    /// - Parameters:
    ///   - destination: Where the finished file goes. Its folder also holds the partial file, so the final
    ///     move stays on one volume and is atomic.
    ///   - onFinish: Called once on `queue` when the download has succeeded or failed.
    init(
        remote: URL,
        destination: URL,
        configuration: URLSessionConfiguration = .default,
        onFinish: @escaping @Sendable (CachingResourceLoader, _ succeeded: Bool) -> Void
    ) {
        self.remote = remote
        self.destination = destination
        partial = destination.deletingLastPathComponent().appending(path: "\(UUID().uuidString).part")
        self.configuration = configuration
        self.onFinish = onFinish
    }

    deinit {
        try? writer?.close()
        try? reader?.close()
    }

    /// The URL to give `AVURLAsset`: the remote one with a scheme only this loader handles.
    static func assetURL(for remote: URL) -> URL? {
        guard var components = URLComponents(url: remote, resolvingAgainstBaseURL: false),
              let scheme = components.scheme else { return nil }
        components.scheme = schemePrefix + scheme
        return components.url
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        if let failure {
            loadingRequest.finishLoading(with: failure)
            return true
        }
        pending.append(loadingRequest)
        startIfNeeded()
        servePending()
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        pending.removeAll { $0 === loadingRequest }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            completionHandler(.cancel)
            fail(URLError(.badServerResponse))
            return
        }
        do {
            try openPartialFile()
        } catch {
            completionHandler(.cancel)
            fail(error)
            return
        }
        self.response = http
        completionHandler(.allow)
        servePending()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard failure == nil, let writer else { return }
        do {
            try writer.write(contentsOf: data)
            received += Int64(data.count)
        } catch {
            dataTask.cancel()
            fail(error)
            return
        }
        servePending()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        // The session holds its delegate strongly until it is invalidated.
        session.finishTasksAndInvalidate()
        guard failure == nil else { return }
        if let error {
            fail(error)
        } else if response == nil {
            fail(URLError(.badServerResponse))
        } else {
            complete()
        }
    }

    // MARK: - Download

    private func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        let operations = OperationQueue()
        operations.underlyingQueue = queue
        operations.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: operations)
        session.dataTask(with: remote).resume()
    }

    private func openPartialFile() throws {
        guard FileManager.default.createFile(atPath: partial.path(percentEncoded: false), contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        writer = try FileHandle(forWritingTo: partial)
        reader = try FileHandle(forReadingFrom: partial)
    }

    private func complete() {
        isComplete = true
        try? writer?.close()
        writer = nil
        servePending()
        // The open reader keeps working after the move, for ranges the player asks for later.
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: partial, to: destination)
            Self.logger.info("Saved \(self.remote.lastPathComponent, privacy: .public) to session cache")
            onFinish(self, true)
        } catch {
            // Playback keeps working from the partial file; only the replay copy is lost.
            Self.logger.error(
                "Couldn't cache \(self.remote.lastPathComponent, privacy: .public): \(error.localizedDescription)"
            )
            onFinish(self, false)
        }
    }

    private func fail(_ error: any Error) {
        guard failure == nil else { return }
        failure = error
        let requests = pending
        pending = []
        for request in requests {
            request.finishLoading(with: error)
        }
        try? writer?.close()
        try? reader?.close()
        writer = nil
        reader = nil
        try? FileManager.default.removeItem(at: partial)
        Self.logger.error(
            "Couldn't load \(self.remote.lastPathComponent, privacy: .public): \(error.localizedDescription)"
        )
        onFinish(self, false)
    }

    // MARK: - Serving requests

    /// The full length when the server sent it, or once the whole file is here.
    private var knownLength: Int64? {
        if let expected = response?.expectedContentLength, expected >= 0 {
            return expected
        }
        return isComplete ? received : nil
    }

    private func servePending() {
        guard response != nil else { return }
        var waiting: [AVAssetResourceLoadingRequest] = []
        for request in pending where !serve(request) {
            waiting.append(request)
        }
        pending = waiting
    }

    /// Answers what has arrived for `request`. Returns true once the request is finished.
    private func serve(_ request: AVAssetResourceLoadingRequest) -> Bool {
        guard let response else { return false }
        if let information = request.contentInformationRequest {
            guard let length = knownLength else { return false }
            information.contentType = response.mimeType.flatMap { UTType(mimeType: $0)?.identifier }
                ?? AVFileType.mp4.rawValue
            information.contentLength = length
            information.isByteRangeAccessSupported = true
        }
        guard let dataRequest = request.dataRequest else {
            request.finishLoading()
            return true
        }

        let end: Int64? = dataRequest.requestsAllDataToEndOfResource
            ? knownLength
            : dataRequest.requestedOffset + Int64(dataRequest.requestedLength)
        let available = min(end ?? received, received)
        var offset = dataRequest.currentOffset
        do {
            while offset < available {
                let chunk = try read(at: offset, count: min(available - offset, Self.chunkSize))
                guard !chunk.isEmpty else { break }
                dataRequest.respond(with: chunk)
                offset += Int64(chunk.count)
            }
        } catch {
            request.finishLoading(with: error)
            return true
        }

        // A range that reaches past the end of a finished file gets what there is.
        if offset >= (end ?? .max) || (isComplete && offset >= received) {
            request.finishLoading()
            return true
        }
        return false
    }

    private func read(at offset: Int64, count: Int64) throws -> Data {
        guard let reader else { throw CocoaError(.fileReadUnknown) }
        try reader.seek(toOffset: UInt64(offset))
        return try reader.read(upToCount: Int(count)) ?? Data()
    }
}
