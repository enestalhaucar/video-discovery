import SwiftUI

/// A heart that saves or removes a video, with a bounce, a small burst and a light haptic.
struct FavoriteButton: View {
    enum Style {
        /// Floating over artwork, on a material circle.
        case overlay
        /// Inline in a row or a toolbar.
        case plain
    }

    let video: Video
    var style: Style = .plain

    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burstCount = 0

    var body: some View {
        let isFavorite = favoritesStore.isFavorite(video)
        Button {
            withAnimation(isFavorite ? Motion.heartOff : Motion.heartOn) {
                favoritesStore.toggle(video)
            }
            if !isFavorite {
                burstCount += 1
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(style == .overlay ? .body.weight(.semibold) : .title3)
                .foregroundStyle(isFavorite ? AnyShapeStyle(.pink) : unselectedStyle)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: reduceMotion ? false : isFavorite)
                .frame(width: 36, height: 36)
                .background {
                    if style == .overlay {
                        Circle().fill(.ultraThinMaterial)
                    }
                }
                .overlay {
                    if !reduceMotion {
                        HeartBurst(trigger: burstCount)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.impact(weight: .light), trigger: isFavorite)
        .accessibilityLabel(isFavorite ? "Remove from Favourites" : "Add to Favourites")
    }

    private var unselectedStyle: AnyShapeStyle {
        style == .overlay ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
    }
}

/// Six dots that fly out of the heart and fade.
private struct HeartBurst: View {
    let trigger: Int

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(.pink)
                    .frame(width: 4, height: 4)
                    .offset(y: -14)
                    .rotationEffect(.degrees(Double(index) * 60))
            }
        }
        .keyframeAnimator(initialValue: 1.0, trigger: trigger) { dots, progress in
            dots
                .scaleEffect(0.6 + progress)
                .opacity(progress < 1 ? 1 - progress : 0)
        } keyframes: { _ in
            MoveKeyframe(0.0)
            CubicKeyframe(1.0, duration: Motion.heartBurstDuration)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        FavoriteButton(video: Video.samples[1])
        FavoriteButton(video: Video.samples[2], style: .overlay)
            .padding()
            .background(.teal)
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
