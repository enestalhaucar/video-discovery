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
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: offset * proxy.size.width * 1.6)
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
