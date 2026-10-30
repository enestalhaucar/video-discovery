import SwiftUI

struct VideoDetailView: View {
    let video: Video

    @State private var player: PlayerModel
    @State private var skipEvent: SkipEvent?
    @State private var skipCount = 0
    @Environment(\.isTabActive) private var isTabActive
    @Environment(\.scenePhase) private var scenePhase

    init(video: Video) {
        self.video = video
        _player = State(initialValue: PlayerModel(url: video.videoURL))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                stage
                if player.phase != .failed {
                    PlaybackControls(player: player, onSkip: flashSkip)
                        .transition(.opacity)
                }
                info
            }
            .padding(.bottom, Theme.Space.pt24)
            .animation(Motion.crossfade, value: player.phase == .failed)
        }
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteButton(video: video)
            }
        }
        .task(id: skipEvent?.id) {
            guard skipEvent != nil else { return }
            try? await Task.sleep(for: .seconds(Motion.skipPillDuration))
            guard !Task.isCancelled else { return }
            skipEvent = nil
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

    /// Edge to edge, 16:9, on black.
    private var stage: some View {
        PlayerSurface(player: player.player)
            .background(Theme.stage)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay { PlayerStageOverlay(player: player, skip: skipEvent) }
            .clipped()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Video player")
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: Theme.Space.pt8) {
            Text(video.title)
                .font(.title2.bold())
                .foregroundStyle(Theme.label)
            CategoryTag(category: video.category)
            Text(video.description)
                .font(.body)
                .foregroundStyle(Theme.labelSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Space.pt16)
        .padding(.top, Theme.Space.pt24)
    }

    private func flashSkip(_ direction: SkipDirection) {
        skipCount += 1
        skipEvent = SkipEvent(direction: direction, id: skipCount)
    }
}

#Preview {
    NavigationStack {
        VideoDetailView(video: Video.samples[1])
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
