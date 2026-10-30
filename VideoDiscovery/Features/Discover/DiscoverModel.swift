import Foundation
import Observation

/// Loads the catalogue once and reveals it in batches, or searches all of it.
@MainActor
@Observable
final class DiscoverModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(message: String)
    }

    static let batchSize = 3

    private(set) var state: LoadState = .idle
    private(set) var catalogue: [Video] = []
    private(set) var visibleCount = 0
    var query = ""

    @ObservationIgnored private let service: CatalogServicing

    init(service: CatalogServicing) {
        self.service = service
    }

    var isSearching: Bool {
        !trimmedQuery.isEmpty
    }

    /// The revealed batches, or every title match across the whole catalogue while searching.
    var displayedVideos: [Video] {
        guard isSearching else { return Array(catalogue.prefix(visibleCount)) }
        return catalogue.filter { $0.title.localizedStandardContains(trimmedQuery) }
    }

    var canRevealMore: Bool {
        !isSearching && visibleCount < catalogue.count
    }

    func load() async {
        guard state == .idle else { return }
        await fetch()
    }

    func retry() async {
        guard case .failed = state else { return }
        await fetch()
    }

    /// Shows up to one more batch from the already fetched catalogue.
    func revealMore() {
        guard canRevealMore else { return }
        visibleCount = min(visibleCount + Self.batchSize, catalogue.count)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fetch() async {
        state = .loading
        do {
            catalogue = try await service.fetchCatalog()
            visibleCount = min(Self.batchSize, catalogue.count)
            state = .loaded
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }
}
