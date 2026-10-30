import SwiftUI

// Placeholder until the designed Discover feed lands.
struct DiscoverView: View {
    @Bindable var model: DiscoverModel

    var body: some View {
        List {
            switch model.state {
            case .idle, .loading:
                ProgressView()
            case .failed(let message):
                Text(message)
                Button("Try again") {
                    Task { await model.retry() }
                }
            case .loaded:
                ForEach(model.displayedVideos) { video in
                    NavigationLink(video.title, value: video)
                }
                if model.canRevealMore {
                    ProgressView()
                        .onAppear { model.revealMore() }
                }
            }
        }
        .searchable(text: $model.query, prompt: "Search videos")
        .navigationTitle("Discover")
    }
}

#Preview {
    NavigationStack {
        DiscoverView(model: DiscoverModel(service: StubCatalogService()))
    }
}
