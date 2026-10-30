import SwiftUI

/// The playback position bar: a 4 pt track with an accent fill, a thumb that grows while dragged, and a time bubble
/// above it. Seeks once, when the finger lifts.
struct Scrubber: View {
    let currentTime: Double
    let duration: Double
    /// The drag position in seconds while a finger is down, nil otherwise, for the times row.
    @Binding var dragTime: Double?
    let onSeek: (Double) -> Void
    let onAdjust: (Double) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var gestureTime: Double?

    private enum Metrics {
        /// How far the bubble's bottom edge reaches into the top of the 44 pt row.
        static let bubbleOverlap: CGFloat = 4
        static let bubbleInsetY: CGFloat = 3
    }

    private var isDragging: Bool { gestureTime != nil }
    private var displayTime: Double { gestureTime ?? currentTime }
    private var progress: Double {
        duration > 0 ? min(max(displayTime / duration, 0), 1) : 0
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let thumbX = width * progress
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.fillSearch)
                    .frame(height: Theme.Size.track)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: thumbX, height: Theme.Size.track)
                thumb
                    .frame(width: 0)
                    .offset(x: thumbX)
                bubbleLayer(thumbX: thumbX, width: width)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(drag(width: width))
        }
        .frame(height: Theme.Size.hit)
        .disabled(duration == 0)
        .onChange(of: gestureTime) { _, newValue in dragTime = newValue }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(
            duration > 0 ? "\(PlaybackClock.text(displayTime)) of \(PlaybackClock.text(duration))" : "Loading"
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onAdjust(SkipDirection.forward.seconds)
            case .decrement: onAdjust(SkipDirection.back.seconds)
            @unknown default: break
            }
        }
    }

    private var thumb: some View {
        let size = isDragging ? Theme.Size.thumbDrag : Theme.Size.thumb
        return Circle()
            .fill(Theme.accent)
            .frame(width: size, height: size)
            .animation(reduceMotion ? nil : Motion.scrub, value: isDragging)
    }

    private func bubbleLayer(thumbX: Double, width: Double) -> some View {
        ZStack {
            if let time = gestureTime {
                Text(PlaybackClock.text(time))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(Theme.background)
                    .padding(.vertical, Metrics.bubbleInsetY)
                    .padding(.horizontal, Theme.Space.pt8)
                    .background(Theme.label, in: Capsule())
                    .fixedSize()
                    // Centred on the thumb, but never hanging off either end of the track.
                    .alignmentGuide(.leading) { dims in
                        dims.width / 2 - min(max(thumbX, dims.width / 2), width - dims.width / 2)
                    }
                    .alignmentGuide(.top) { dims in dims[.bottom] - Metrics.bubbleOverlap }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .transition(.opacity)
            }
        }
        .animation(Motion.fadeIn, value: isDragging)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drag(width: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($gestureTime) { value, state, _ in
                guard duration > 0 else { return }
                state = seconds(at: value.location.x, width: width)
            }
            .onEnded { value in
                guard duration > 0 else { return }
                onSeek(seconds(at: value.location.x, width: width))
            }
    }

    private func seconds(at position: Double, width: Double) -> Double {
        guard width > 0 else { return 0 }
        return min(max(position / width, 0), 1) * duration
    }
}
