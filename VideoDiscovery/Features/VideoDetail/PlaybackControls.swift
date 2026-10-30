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

/// The play triangle is lopsided, so it is nudged right to look centred.
enum PlayGlyph {
    static let nudge: CGFloat = 1.5
}

/// Formats seconds as m:ss.
enum PlaybackClock {
    static let unknown = "--:--"

    static func text(_ seconds: Double) -> String {
        guard seconds.isFinite else { return unknown }
        let total = max(Int(seconds.rounded()), 0)
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}

/// The control bar under the stage: scrubber, times, then back 10 · play/pause · forward 10.
struct PlaybackControls: View {
    let player: PlayerModel
    /// Called after a skip button is tapped, so the stage can flash its pill.
    let onSkip: (SkipDirection) -> Void

    @State private var scrubTime: Double?

    private var isLoading: Bool { player.phase == .loading }
    private var hasDuration: Bool { player.duration > 0 }
    private var elapsed: Double { scrubTime ?? player.currentTime }
    /// Pause while playing, and while a play request is still waiting for data.
    private var showsPause: Bool { player.phase == .playing || player.isBuffering }

    var body: some View {
        VStack(spacing: 0) {
            Scrubber(
                currentTime: player.currentTime,
                duration: player.duration,
                dragTime: $scrubTime,
                onSeek: { player.seek(to: $0) },
                onAdjust: { player.skip(by: $0) }
            )
            times
                .padding(.top, -Theme.Space.pt8)
            transport
                .padding(.top, Theme.Space.pt4)
        }
        .padding(.top, Theme.Space.pt12)
        .padding(.horizontal, Theme.Space.pt16)
        .padding(.bottom, Theme.Space.pt8)
        .opacity(isLoading ? Theme.Opacity.dimmed : 1)
        .disabled(isLoading)
        .animation(Motion.crossfade, value: isLoading)
    }

    private var times: some View {
        HStack {
            Text(hasDuration ? PlaybackClock.text(elapsed) : PlaybackClock.unknown)
            Spacer()
            Text(hasDuration ? "-" + PlaybackClock.text(max(player.duration - elapsed, 0)) : PlaybackClock.unknown)
        }
        .font(.caption.weight(.medium).monospacedDigit())
        .foregroundStyle(Theme.labelSecondary)
        // The scrubber already reads out "0:03 of 0:10".
        .accessibilityHidden(true)
    }

    private var transport: some View {
        HStack(spacing: Theme.Space.pt32) {
            SkipButton(direction: .back) { skip(.back) }
            PlayPauseButton(showsPause: showsPause) { player.togglePlayback() }
            SkipButton(direction: .forward) { skip(.forward) }
        }
        .frame(maxWidth: .infinity)
    }

    private func skip(_ direction: SkipDirection) {
        player.skip(by: direction.seconds)
        onSkip(direction)
    }
}

/// The 56 pt accent circle. The symbol morphs between play and pause.
private struct PlayPauseButton: View {
    let showsPause: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: showsPause ? "pause.fill" : "play.fill")
                .font(.title2)
                .foregroundStyle(Theme.onAccent)
                .contentTransition(.symbolEffect(.replace))
                .animation(Motion.crossfade, value: showsPause)
                .offset(x: showsPause ? 0 : PlayGlyph.nudge)
                .frame(width: Theme.Size.play, height: Theme.Size.play)
                .background(Theme.accent, in: Circle())
        }
        .buttonStyle(PressedScaleStyle())
        .accessibilityLabel(showsPause ? "Pause" : "Play")
    }
}

/// Back or forward 10 seconds. The arrow tilts 30 degrees its way and back on each tap.
private struct SkipButton: View {
    let direction: SkipDirection
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilt = 0.0

    private enum Metrics {
        static let tiltDegrees = 30.0
    }

    var body: some View {
        Button {
            action()
            nudge()
        } label: {
            Image(systemName: direction == .back ? "gobackward.10" : "goforward.10")
                .font(.title2)
                .foregroundStyle(Theme.label)
                .rotationEffect(.degrees(tilt))
                .frame(width: Theme.Size.hit, height: Theme.Size.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedOpacityStyle())
        .accessibilityLabel(direction == .back ? "Back 10 seconds" : "Forward 10 seconds")
    }

    private func nudge() {
        guard !reduceMotion else { return }
        let angle = direction == .back ? -Metrics.tiltDegrees : Metrics.tiltDegrees
        withAnimation(Motion.skipRotation, completionCriteria: .logicallyComplete) {
            tilt = angle
        } completion: {
            withAnimation(Motion.skipRotation) { tilt = 0 }
        }
    }
}
