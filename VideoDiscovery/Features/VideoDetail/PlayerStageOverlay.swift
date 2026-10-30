import SwiftUI

/// Which way a skip button moves the playhead.
enum SkipDirection {
    case back, forward

    var seconds: Double {
        switch self {
        case .back: -10
        case .forward: 10
        }
    }
}

/// One skip request. The id makes two skips in a row in the same direction distinct, so the pill restarts.
struct SkipEvent: Equatable {
    let direction: SkipDirection
    let id: Int
}

/// Extra timings that the shared `Motion` set doesn't carry.
enum StageMotion {
    /// Buffering spinner and the scrubber's time bubble fading in.
    static let fadeIn = Animation.easeOut(duration: 0.15)
}

/// Scales down while pressed. Under Reduce Motion it dims instead.
struct PressedScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed && reduceMotion ? Theme.Opacity.pressed : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// Everything that sits on top of the video: spinners, the play button, Replay, the failure message and the
/// skip pill. The playback controls are never drawn here.
struct PlayerStageOverlay: View {
    let player: PlayerModel
    let skip: SkipEvent?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        /// Where the skip pill sits, as a share of the stage width, measured from its own edge.
        static let pillInset = 0.18
        /// The play triangle is lopsided, so it is nudged right to look centred.
        static let playNudge: CGFloat = 1.5
        static let replayInset: CGFloat = 18
        static let failureTitleGap: CGFloat = 6
    }

    private var showsLoading: Bool { player.phase == .loading }
    private var showsPlay: Bool { player.phase == .ready && !player.isBuffering }
    private var showsBuffering: Bool {
        player.isBuffering && player.phase != .loading && player.phase != .failed
    }
    private var showsReplay: Bool { player.phase == .ended }
    private var showsFailure: Bool { player.phase == .failed }

    var body: some View {
        ZStack {
            loadingLayer
            playLayer
            bufferingLayer
            replayLayer
            failureLayer
            skipLayer
        }
        .foregroundStyle(Theme.onStage)
        // The stage has a fixed height, so the text on it stops growing before it would spill out.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    // MARK: Layers

    private var loadingLayer: some View {
        ZStack {
            if showsLoading {
                StageSpinner()
                    .accessibilityLabel("Loading video")
                    .transition(.opacity)
            }
        }
        .animation(Motion.crossfade, value: showsLoading)
    }

    /// Appears at once; on play it scales to 0.8 while fading out.
    private var playLayer: some View {
        ZStack {
            if showsPlay {
                Button {
                    player.play()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .offset(x: Metrics.playNudge)
                        .frame(width: Theme.Size.overlayPlay, height: Theme.Size.overlayPlay)
                        .background(Theme.stageMaterial, in: Circle())
                }
                .buttonStyle(PressedScaleStyle())
                .accessibilityLabel("Play")
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(insertion: .identity, removal: .scale(scale: 0.8).combined(with: .opacity))
                )
            }
        }
        .animation(showsPlay ? nil : Motion.overlay, value: showsPlay)
    }

    private var bufferingLayer: some View {
        ZStack {
            if showsBuffering {
                BufferingSpinner()
            }
        }
    }

    private var replayLayer: some View {
        ZStack {
            if showsReplay {
                Button {
                    player.replay()
                } label: {
                    HStack(spacing: Theme.Space.pt8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Replay")
                    }
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, Metrics.replayInset)
                    .frame(minHeight: Theme.Size.hit)
                    .background(Theme.stageMaterial, in: Capsule())
                }
                .buttonStyle(PressedOpacityStyle())
                .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(Motion.crossfade, value: showsReplay)
    }

    private var failureLayer: some View {
        ZStack {
            if showsFailure {
                FailureMessage(titleGap: Metrics.failureTitleGap) { player.retry() }
            }
        }
    }

    private var skipLayer: some View {
        GeometryReader { proxy in
            if let skip {
                let isBack = skip.direction == .back
                SkipPill(direction: skip.direction)
                    .id(skip.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isBack ? .leading : .trailing)
                    .padding(isBack ? .leading : .trailing, proxy.size.width * Metrics.pillInset)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Pieces

private struct StageSpinner: View {
    var body: some View {
        ProgressView()
            .controlSize(.large)
            .tint(Theme.onStage)
    }
}

/// Only shows if buffering lasts longer than `Motion.bufferingDelay`, then fades in.
private struct BufferingSpinner: View {
    @State private var isVisible = false

    var body: some View {
        StageSpinner()
            .opacity(isVisible ? 1 : 0)
            .accessibilityLabel("Buffering")
            .task {
                try? await Task.sleep(for: .seconds(Motion.bufferingDelay))
                guard !Task.isCancelled else { return }
                withAnimation(StageMotion.fadeIn) { isVisible = true }
            }
    }
}

/// "Can’t play this video", with Try again. Fades in while rising 8 pt (cross-fades under Reduce Motion).
private struct FailureMessage: View {
    let titleGap: CGFloat
    let onRetry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        VStack(spacing: Theme.Space.pt4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
            Text("Can’t play this video")
                .font(.headline)
                .padding(.top, titleGap)
            Text("Something went wrong while loading it.")
                .font(.subheadline)
                .foregroundStyle(Theme.onStageSecondary)
            Button("Try again", action: onRetry)
                .buttonStyle(StageButtonStyle())
                .padding(.top, Theme.Space.pt12)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Theme.Space.pt24)
        .opacity(isShown ? 1 : 0)
        .offset(y: isShown || reduceMotion ? 0 : Theme.Space.pt8)
        .onAppear {
            withAnimation(reduceMotion ? Motion.crossfade : Motion.failure) { isShown = true }
        }
    }
}

/// The white outlined capsule button on the stage.
private struct StageButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let minWidth: CGFloat = 120
        static let minHeight: CGFloat = 36
        static let stroke: CGFloat = 1.5
        static let pressedScale: CGFloat = 0.97
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.onStage)
            .padding(.horizontal, Theme.Space.pt20)
            .frame(minWidth: Metrics.minWidth, minHeight: Metrics.minHeight)
            .background(configuration.isPressed ? Theme.stageMaterial : .clear, in: Capsule())
            .overlay { Capsule().strokeBorder(Theme.onStage, lineWidth: Metrics.stroke) }
            // The capsule is 36 pt tall; the touch target is still 44.
            .contentShape(.interaction, Capsule().inset(by: -(Theme.Size.hit - Metrics.minHeight) / 2))
            .scaleEffect(configuration.isPressed && !reduceMotion ? Metrics.pressedScale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// The "−10s" / "+10s" flash: in over the first quarter, held, out over the last 30 %.
private struct SkipPill: View {
    let direction: SkipDirection

    @State private var opacity = 0.0

    var body: some View {
        Text(direction == .back ? "\u{2212}10s" : "+10s")
            .font(.subheadline)
            .foregroundStyle(Theme.onStage)
            .padding(.vertical, 6)
            .padding(.horizontal, Theme.Space.pt12)
            .background(Theme.stageMaterial, in: Capsule())
            .opacity(opacity)
            .task {
                let total = Motion.skipPillDuration
                withAnimation(.easeOut(duration: total * 0.25)) { opacity = 1 }
                try? await Task.sleep(for: .seconds(total * 0.7))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: total * 0.3)) { opacity = 0 }
            }
    }
}
