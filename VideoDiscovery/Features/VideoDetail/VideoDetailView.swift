import SwiftUI

struct VideoDetailView: View {
    let video: Video

    @State private var player: PlayerModel
    @State private var skipEvent: SkipEvent?
    @State private var skipCount = 0
    @State private var hasAutoPlayed = false
    @State private var isFullscreen = false
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
        .onAppear {
            player.activate()
            // Plays straight away on the first visit only; coming back after a pause stays paused.
            if !hasAutoPlayed {
                hasAutoPlayed = true
                player.play()
            }
        }
        .onDisappear {
            // The full-screen cover hides this screen but keeps using its player.
            if !isFullscreen { player.deactivate() }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            FullscreenPlayerView(player: player)
        }
        .onChange(of: isTabActive) { _, isActive in
            if !isActive { player.pause() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { player.pause() }
        }
        .onChange(of: player.phase) { _, phase in
            // The control bar disappears on failure, so VoiceOver users hear why.
            if phase == .failed {
                AccessibilityNotification.Announcement(String(localized: "Can’t play this video")).post()
            }
        }
    }

    /// Edge to edge, 16:9, on black. Pinch to zoom; the corner button opens full screen.
    private var stage: some View {
        ZoomableVideo(player: player.player)
            .background(Theme.stage)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay { PlayerStageOverlay(player: player, skip: skipEvent) }
            .overlay(alignment: .bottomTrailing) {
                if player.phase != .failed {
                    fullscreenButton
                }
            }
            .clipped()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Video player")
    }

    private var fullscreenButton: some View {
        Button("Full screen", systemImage: "arrow.up.left.and.arrow.down.right") {
            isFullscreen = true
        }
        .labelStyle(.iconOnly)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.onStage)
        .frame(width: Theme.Size.heart, height: Theme.Size.heart)
        .background(Theme.stageMaterial, in: Circle())
        .frame(width: Theme.Size.hit, height: Theme.Size.hit)
        .buttonStyle(PressedOpacityStyle())
        .padding(Theme.Space.pt4)
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
