import Foundation

protocol CatalogServicing: Sendable {
    /// Fetches the whole catalogue in a single request.
    func fetchCatalog() async throws -> [Video]
}

enum CatalogError: LocalizedError, Equatable {
    case offline
    case server(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .offline:
            String(localized: "Check your connection and try again.")
        case .server:
            String(localized: "The server had a problem. Try again in a moment.")
        case .invalidResponse:
            String(localized: "The videos couldn't be read. Try again later.")
        }
    }
}

struct RemoteCatalogService: CatalogServicing {
    // swiftlint:disable:next force_unwrapping
    static let catalogURL = URL(string: "https://api.npoint.io/97e6831c04349c4d1f82")!

    private let url: URL
    private let session: URLSession

    init(url: URL = Self.catalogURL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    func fetchCatalog() async throws -> [Video] {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is URLError {
            throw CatalogError.offline
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CatalogError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CatalogError.server(statusCode: httpResponse.statusCode)
        }
        do {
            return try JSONDecoder().decode(CatalogResponse.self, from: data).videos
        } catch {
            throw CatalogError.invalidResponse
        }
    }
}
