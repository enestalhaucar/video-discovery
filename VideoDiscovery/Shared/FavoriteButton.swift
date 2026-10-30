import SwiftUI

/// The favourite toggle: pops with a burst when saved, dips when removed, with a light haptic.
struct FavoriteButton: View {
    enum Style {
        /// Floating over artwork, on a thin material disc.
        case float
        /// Inline in a row or the navigation bar.
        case plain
    }

    let video: Video
    var style: Style = .plain

    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popCount = 0
    @State private var dipCount = 0

    var body: some View {
        let isFavorite = favoritesStore.isFavorite(video)
        let animates = !reduceMotion
        Button {
            if isFavorite {
                dipCount += 1
            } else {
                popCount += 1
            }
            withAnimation(Motion.listChange) {
                favoritesStore.toggle(video)
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(style == .float ? .body.weight(.semibold) : .title3)
                .foregroundStyle(isFavorite ? Theme.accent : Theme.label)
                .contentTransition(.symbolEffect(.replace))
                .keyframeAnimator(initialValue: 1.0, trigger: popCount) { glyph, scale in
                    glyph.scaleEffect(animates ? scale : 1)
                } keyframes: { _ in
                    SpringKeyframe(1.3, duration: 0.14, spring: .snappy)
                    SpringKeyframe(1.0, spring: Motion.heartPop)
                }
                .keyframeAnimator(initialValue: 1.0, trigger: dipCount) { glyph, scale in
                    glyph.scaleEffect(animates ? scale : 1)
                } keyframes: { _ in
                    SpringKeyframe(0.85, duration: 0.1, spring: .snappy)
                    SpringKeyframe(1.0, spring: Motion.heartDip)
                }
                .frame(width: Theme.Size.heart, height: Theme.Size.heart)
                .background {
                    if style == .float {
                        Circle().fill(.thinMaterial)
                    }
                }
                .overlay {
                    if !reduceMotion {
                        HeartBurst(trigger: popCount)
                    }
                }
                .frame(width: Theme.Size.hit, height: Theme.Size.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedOpacityStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: isFavorite)
        .accessibilityLabel(isFavorite ? "Remove from favourites" : "Save to favourites")
        .accessibilityValue(video.title)
        .accessibilityAddTraits(isFavorite ? .isSelected : [])
    }
}

/// Six accent dots that fly out of the heart and fade.
private struct HeartBurst: View {
    let trigger: Int

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(Theme.accent)
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
        FavoriteButton(video: Video.samples[2], style: .float)
            .padding()
            .background(.teal)
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
