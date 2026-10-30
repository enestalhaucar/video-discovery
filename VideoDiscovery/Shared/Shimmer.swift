import SwiftUI

extension View {
    /// Sweeps a soft highlight across the view, for loading skeletons. Static with Reduce Motion.
    func shimmering() -> some View {
        modifier(Shimmer())
    }
}

private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.3),
                                .init(color: Theme.skeletonSheen, location: 0.5),
                                .init(color: .clear, location: 0.7)
                            ],
                            startPoint: UnitPoint(x: 0, y: 0.4),
                            endPoint: UnitPoint(x: 1, y: 0.6)
                        )
                        .frame(width: proxy.size.width)
                        .offset(x: offset * proxy.size.width)
                    }
                    .mask(content)
                    .onAppear {
                        withAnimation(.linear(duration: Motion.shimmerDuration).repeatForever(autoreverses: false)) {
                            offset = 1
                        }
                    }
                }
            }
    }
}
