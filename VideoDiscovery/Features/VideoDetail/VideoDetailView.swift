import SwiftUI

struct VideoDetailView: View {
    let video: Video

    @State private var player: PlayerModel
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(\.isTabActive) private var isTabActive
    @Environment(\.scenePhase) private var scenePhase

    init(video: Video) {
        self.video = video
        _player = State(initialValue: PlayerModel(url: video.videoURL))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PlayerSurface(player: player.player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay { stageOverlay }
                if player.phase != .failed {
                    controls
                        .padding(.horizontal)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title)
                        .font(.title2.bold())
                    Text(video.category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(video.description)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(
                favoritesStore.isFavorite(video) ? "Remove from Favourites" : "Add to Favourites",
                systemImage: favoritesStore.isFavorite(video) ? "heart.fill" : "heart"
            ) {
                favoritesStore.toggle(video)
            }
        }
        .onAppear { player.activate() }
        .onDisappear { player.deactivate() }
        .onChange(of: isTabActive) { _, isActive in
            if !isActive { player.pause() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { player.pause() }
        }
    }

    @ViewBuilder private var stageOverlay: some View {
        switch player.phase {
        case .loading:
            ProgressView().tint(.white)
        case .failed:
            VStack(spacing: 8) {
                Text("Can't play this video")
                    .font(.headline)
                Button("Try again") { player.retry() }
                    .buttonStyle(.bordered)
            }
            .foregroundStyle(.white)
        case .ended:
            Button("Replay", systemImage: "arrow.counterclockwise") { player.replay() }
                .buttonStyle(.bordered)
                .tint(.white)
        case .ready, .playing, .paused:
            if player.isBuffering {
                ProgressView().tint(.white)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                in: 0...max(player.duration, 0.1)
            )
            .disabled(player.duration == 0)
            HStack {
                Button("Back 10 seconds", systemImage: "gobackward.10") { player.skip(by: -10) }
                Spacer()
                Button(
                    player.phase == .playing ? "Pause" : "Play",
                    systemImage: player.phase == .playing ? "pause.fill" : "play.fill"
                ) {
                    player.togglePlayback()
                }
                Spacer()
                Button("Forward 10 seconds", systemImage: "goforward.10") { player.skip(by: 10) }
            }
            .labelStyle(.iconOnly)
            .font(.title2)
        }
    }
}

#Preview {
    NavigationStack {
        VideoDetailView(video: Video.samples[1])
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
