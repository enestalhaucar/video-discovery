import AVFoundation
import SwiftUI

/// The video surface with pinch to zoom (1× to 3×), drag to pan while zoomed and double-tap to reset.
struct ZoomableVideo: View {
    let player: AVPlayer

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var pan: CGSize = .zero

    private enum Metrics {
        static let maxScale: CGFloat = 3
    }

    var body: some View {
        GeometryReader { proxy in
            let currentScale = clampedScale(scale * pinch)
            PlayerSurface(player: player)
                .scaleEffect(currentScale)
                .offset(clampedOffset(offset + pan, scale: currentScale, in: proxy.size))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(magnify(in: proxy.size))
                // Panning only takes over from scrolling once the video is zoomed in.
                .gesture(drag(in: proxy.size), including: scale > 1 ? .all : .none)
                .onTapGesture(count: 2) {
                    withAnimation(Motion.release) { reset() }
                }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private func magnify(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                withAnimation(Motion.release) {
                    scale = clampedScale(scale * value.magnification)
                    if scale == 1 {
                        offset = .zero
                    } else {
                        offset = clampedOffset(offset, scale: scale, in: size)
                    }
                }
            }
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture()
            .updating($pan) { value, state, _ in state = value.translation }
            .onEnded { value in
                offset = clampedOffset(offset + value.translation, scale: scale, in: size)
            }
    }

    private func reset() {
        scale = 1
        offset = .zero
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), Metrics.maxScale)
    }

    /// Keeps the zoomed video covering the frame: it can't be dragged past its own edges.
    private func clampedOffset(_ value: CGSize, scale: CGFloat, in size: CGSize) -> CGSize {
        let maxX = size.width * (scale - 1) / 2
        let maxY = size.height * (scale - 1) / 2
        return CGSize(
            width: min(max(value.width, -maxX), maxX),
            height: min(max(value.height, -maxY), maxY)
        )
    }
}

private extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}
