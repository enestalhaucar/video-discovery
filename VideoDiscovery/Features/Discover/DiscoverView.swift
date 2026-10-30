import SwiftUI

struct DiscoverView: View {
    @Bindable var model: DiscoverModel
    let zoomNamespace: Namespace.ID

    var body: some View {
        // One scroll view for every state keeps the large title tracking it.
        ScrollView {
            LazyVStack(spacing: 24) {
                if isLoading {
                    ForEach(0..<DiscoverModel.batchSize, id: \.self) { _ in
                        SkeletonCard()
                    }
                    .transition(.opacity)
                } else {
                    ForEach(Array(model.displayedVideos.enumerated()), id: \.element.id) { index, video in
                        VideoCard(video: video, zoomNamespace: zoomNamespace)
                            .transition(revealTransition(index: index))
                    }
                    footer
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .animation(Motion.crossfade, value: model.query)
        }
        .scrollDisabled(isLoading)
        .overlay { emptyState }
        .animation(Motion.contentFade, value: model.state)
        .navigationTitle("Discover")
        // Always visible, so search is easy to find; on iOS 26+ this keeps the title inline.
        .searchable(
            text: $model.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search videos"
        )
    }

    private var isLoading: Bool {
        model.state == .idle || model.state == .loading
    }

    @ViewBuilder private var emptyState: some View {
        switch model.state {
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load videos", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task { await model.retry() }
                }
                .buttonStyle(.bordered)
            }
            .transition(.opacity)
        case .loaded where model.catalogue.isEmpty:
            ContentUnavailableView(
                "No videos yet",
                systemImage: "film.stack",
                description: Text("New videos will show up here.")
            )
            .transition(.opacity)
        case .loaded where model.displayedVideos.isEmpty:
            ContentUnavailableView.search(text: model.query)
                .transition(.opacity)
        default:
            EmptyView()
        }
    }

    /// New cards fade in and rise, one after another within a batch.
    private func revealTransition(index: Int) -> AnyTransition {
        let delay = Double(index % DiscoverModel.batchSize) * Motion.revealStagger
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: Motion.revealOffset)),
            removal: .opacity
        )
        .animation(Motion.reveal.delay(delay))
    }

    @ViewBuilder private var footer: some View {
        if model.canRevealMore {
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading more…")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            // Reveal only once the footer is actually on screen, not when the lazy stack prepares it.
            .onGeometryChange(for: Bool.self) { proxy in
                let visibleHeight = proxy.bounds(of: .scrollView)?.height ?? 0
                return proxy.frame(in: .scrollView).minY < visibleHeight
            } action: { isVisible in
                if isVisible {
                    withAnimation(Motion.reveal) { model.revealMore() }
                }
            }
        } else if !model.isSearching && !model.catalogue.isEmpty {
            Label("You're all caught up", systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.9)).animation(Motion.endOfList))
        }
    }
}

#Preview("Loaded") {
    @Previewable @Namespace var namespace
    NavigationStack {
        DiscoverView(model: DiscoverModel(service: StubCatalogService()), zoomNamespace: namespace)
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}

#Preview("Error") {
    @Previewable @Namespace var namespace
    NavigationStack {
        DiscoverView(model: DiscoverModel(service: StubCatalogService(behavior: .error)), zoomNamespace: namespace)
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
