import SwiftUI

/// Full-screen playback sharing the detail screen's player. It opens in the current orientation and turns to
/// landscape when the user turns the phone. Tap to show or hide the controls.
struct FullscreenPlayerView: View {
    let player: PlayerModel

    @Environment(\.dismiss) private var dismiss
    @State private var showsControls = true
    @State private var skipEvent: SkipEvent?
    @State private var skipCount = 0

    private enum Metrics {
        static let controlsMaxWidth: CGFloat = 640
    }

    var body: some View {
        ZStack {
            Theme.stage
                .ignoresSafeArea()
            ZoomableVideo(player: player.player)
                .ignoresSafeArea()
            PlayerStageOverlay(player: player, skip: skipEvent)
            if showsControls {
                controls
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Motion.crossfade) { showsControls.toggle() }
        }
        // Everything here sits on the black stage, so the dark palette applies.
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { OrientationLock.allow(.allButUpsideDown) }
        // The rest of the app is portrait, so leaving full screen turns back even if the phone is sideways.
        .onDisappear { OrientationLock.force(.portrait) }
    }

    private var controls: some View {
        VStack {
            HStack {
                Button("Exit full screen", systemImage: "arrow.down.right.and.arrow.up.left") {
                    // Turn back first, so the detail screen never shows sideways during the dismissal.
                    OrientationLock.force(.portrait)
                    dismiss()
                }
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.onStage)
                .frame(width: Theme.Size.heart, height: Theme.Size.heart)
                .background(Theme.stageMaterial, in: Circle())
                .frame(width: Theme.Size.hit, height: Theme.Size.hit)
                .buttonStyle(PressedOpacityStyle())
                Spacer()
            }
            Spacer()
            if player.phase != .failed {
                PlaybackControls(player: player) { direction in
                    skipCount += 1
                    skipEvent = SkipEvent(direction: direction, id: skipCount)
                }
                .frame(maxWidth: Metrics.controlsMaxWidth)
                .background(Theme.stageMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                // Taps between the controls shouldn't hide the panel.
                .contentShape(Rectangle())
                .onTapGesture {}
            }
        }
        .padding(Theme.Space.pt16)
    }
}
