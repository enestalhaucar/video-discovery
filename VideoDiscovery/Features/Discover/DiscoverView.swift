import SwiftUI

struct DiscoverView: View {
    @Bindable var model: DiscoverModel
    let zoomNamespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // While a retry is in flight the error stays on screen with a spinner in its button.
    @State private var isRetrying = false
    @State private var lastError = ""

    var body: some View {
        // One scroll view for every state keeps the navigation title tracking it.
        ScrollView {
            SearchField(text: $model.query)
                .padding(.horizontal, Theme.Space.pt16)
                .padding(.bottom, Theme.Space.pt8)
            LazyVStack(spacing: Theme.Space.pt20) {
                if showsSkeleton {
                    ForEach(0..<DiscoverModel.batchSize, id: \.self) { _ in
                        SkeletonCard()
                    }
                    .transition(.opacity)
                } else if model.state == .loaded {
                    ForEach(Array(model.displayedVideos.enumerated()), id: \.element.id) { index, video in
                        VideoCard(video: video, zoomNamespace: zoomNamespace)
                            .transition(revealTransition(index: index))
                    }
                    footer
                }
            }
            .padding(.horizontal, Theme.Space.pt16)
            .animation(Motion.crossfade, value: model.query)
        }
        .scrollDisabled(showsSkeleton)
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.background)
        .overlay { stateView }
        .animation(Motion.contentFade, value: model.state)
        .onChange(of: model.state) { _, state in
            if case .failed(let message) = state {
                lastError = message
            }
        }
        .navigationTitle("Discover")
    }

    private var showsSkeleton: Bool {
        model.state == .idle || (model.state == .loading && !isRetrying)
    }

    @ViewBuilder private var stateView: some View {
        if case .failed = model.state {
            errorView
        } else if isRetrying {
            errorView
        } else if model.state == .loaded, model.catalogue.isEmpty {
            StateView(symbol: "film.stack", title: "No videos yet", message: "New videos will show up here.")
                .transition(.opacity)
        } else if model.state == .loaded, model.displayedVideos.isEmpty {
            StateView(
                symbol: "magnifyingglass",
                title: "No results for “\(model.query.trimmingCharacters(in: .whitespaces))”",
                message: "Try a different title."
            )
            .transition(.opacity)
        }
    }

    private var errorView: some View {
        StateView(
            symbol: "wifi.exclamationmark",
            title: "Couldn’t load videos",
            message: lastError.isEmpty ? nil : lastError,
            actionTitle: "Try again",
            isLoading: isRetrying
        ) {
            isRetrying = true
            Task {
                await model.retry()
                isRetrying = false
            }
        }
        .transition(.opacity)
    }

    /// New cards fade in and rise, one after another within a batch.
    private func revealTransition(index: Int) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let delay = Double(index % DiscoverModel.batchSize) * Motion.revealStagger
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: Motion.revealOffset)),
            removal: .opacity
        )
        .animation(Motion.reveal.delay(delay))
    }

    @ViewBuilder private var footer: some View {
        if model.canRevealMore {
            VStack(spacing: Theme.Space.pt8) {
                ProgressView()
                Text("Loading more…")
                    .font(.subheadline)
            }
            .foregroundStyle(Theme.labelSecondary)
            .frame(maxWidth: .infinity)
            .padding(.bottom, Theme.Space.pt32)
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
            EndOfListView()
        }
    }
}

/// "You’re all caught up" with a checkmark that draws itself.
private struct EndOfListView: View {
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            CheckmarkShape()
                .trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 12, height: 12)
            Text("You’re all caught up")
                .font(.footnote)
        }
        .foregroundStyle(Theme.labelSecondary)
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.pt4)
        .padding(.bottom, Theme.Space.pt32)
        .accessibilityElement(children: .combine)
        .transition(.opacity.animation(Motion.endOfList))
        .onAppear {
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(Motion.endOfList.delay(0.1)) { progress = 1 }
            }
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.maxY * 0.85))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.12))
        return path
    }
}

#Preview("Loaded") {
    @Previewable @Namespace var namespace
    NavigationStack {
        let model = DiscoverModel(service: StubCatalogService())
        DiscoverView(model: model, zoomNamespace: namespace)
            .task { await model.load() }
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}

#Preview("Error") {
    @Previewable @Namespace var namespace
    NavigationStack {
        let model = DiscoverModel(service: StubCatalogService(behavior: .error))
        DiscoverView(model: model, zoomNamespace: namespace)
            .task { await model.load() }
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
