import AVFoundation
import Foundation
import os
import Testing
@testable import VideoDiscovery

struct CachingResourceLoaderTests {
    @Test func assetURLOnlyChangesTheScheme() throws {
        let remote = try #require(URL(string: "https://samplelib.com/mp4/sample-5s.mp4?x=1"))
        let assetURL = try #require(CachingResourceLoader.assetURL(for: remote))
        #expect(assetURL.absoluteString == "vdcache-https://samplelib.com/mp4/sample-5s.mp4?x=1")
    }

    @Test func oneDownloadFeedsThePlayerAndBecomesTheSavedFile() async throws {
        let folder = try Self.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let remote = try #require(URL(string: "https://stub.test/ok-\(UUID().uuidString).mp4"))
        let destination = folder.appending(path: "video.mp4")
        let (finished, continuation) = AsyncStream<Bool>.makeStream()
        let loader = CachingResourceLoader(
            remote: remote,
            destination: destination,
            configuration: StubURLProtocol.configuration
        ) { _, succeeded in
            continuation.yield(succeeded)
        }

        let asset = AVURLAsset(url: try #require(CachingResourceLoader.assetURL(for: remote)))
        asset.resourceLoader.setDelegate(loader, queue: loader.queue)
        // The body isn't a real movie, so loading fails; the requests still go through the loader.
        _ = try? await asset.load(.duration)

        var results = finished.makeAsyncIterator()
        #expect(await results.next() == true)
        #expect(try Data(contentsOf: destination) == StubURLProtocol.body)
        #expect(StubURLProtocol.requestCount(for: remote) == 1)
        #expect(try Self.partialFiles(in: folder).isEmpty)
        withExtendedLifetime(loader) {}
    }

    @Test func anErrorResponseFailsThePlayerAndSavesNothing() async throws {
        let folder = try Self.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let remote = try #require(URL(string: "https://stub.test/forbidden-\(UUID().uuidString).mp4"))
        let destination = folder.appending(path: "video.mp4")
        let (finished, continuation) = AsyncStream<Bool>.makeStream()
        let loader = CachingResourceLoader(
            remote: remote,
            destination: destination,
            configuration: StubURLProtocol.configuration
        ) { _, succeeded in
            continuation.yield(succeeded)
        }

        let asset = AVURLAsset(url: try #require(CachingResourceLoader.assetURL(for: remote)))
        asset.resourceLoader.setDelegate(loader, queue: loader.queue)
        await #expect(throws: (any Error).self) {
            _ = try await asset.load(.duration)
        }

        var results = finished.makeAsyncIterator()
        #expect(await results.next() == false)
        #expect(!FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)))
        #expect(try Self.partialFiles(in: folder).isEmpty)
        #expect(StubURLProtocol.requestCount(for: remote) == 1)
        withExtendedLifetime(loader) {}
    }

    private static func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "LoaderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func partialFiles(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "part" }
    }
}

/// Answers `ok-…` paths with 200 and a fixed body, anything else with a 403 HTML page, and counts requests.
final class StubURLProtocol: URLProtocol {
    static let body = Data((0..<300_000).map { UInt8(truncatingIfNeeded: $0 &* 31) })

    static var configuration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return configuration
    }

    private static let counts = OSAllocatedUnfairLock(initialState: [URL: Int]())

    static func requestCount(for url: URL) -> Int {
        counts.withLock { $0[url] ?? 0 }
    }

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        Self.counts.withLock { $0[url, default: 0] += 1 }
        let isOK = url.lastPathComponent.hasPrefix("ok-")
        let body = isOK ? Self.body : Data("<html>Forbidden</html>".utf8)
        let headers = [
            "Content-Type": isOK ? "video/mp4" : "text/html",
            "Content-Length": "\(body.count)"
        ]
        guard let response = HTTPURLResponse(url: url, statusCode: isOK ? 200 : 403, httpVersion: "HTTP/1.1",
                                             headerFields: headers) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
