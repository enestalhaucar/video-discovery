import SwiftUI

/// A large 16:9 card. The heart sits beside the link, not inside it, so tapping it never navigates.
struct VideoCard: View {
    let video: Video
    let zoomNamespace: Namespace.ID

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: video) {
                VStack(alignment: .leading, spacing: 10) {
                    ThumbnailView(url: video.thumbnailURL)
                        .zoomSource(id: video.id, in: zoomNamespace)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(video.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        CategoryTag(category: video.category)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .buttonStyle(PressableCardStyle())

            FavoriteButton(video: video, style: .overlay)
                .padding(6)
        }
    }
}

/// Shrinks the card slightly while it's pressed.
private struct PressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(configuration.isPressed ? Motion.press : Motion.release, value: configuration.isPressed)
    }
}

/// Grey blocks in the shape of a card, shown while the catalogue loads.
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .aspectRatio(16 / 9, contentMode: .fit)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .frame(width: 180, height: 16)
            Capsule()
                .frame(width: 72, height: 18)
        }
        .foregroundStyle(.quaternary)
        .shimmering()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

#Preview {
    @Previewable @Namespace var namespace
    NavigationStack {
        VStack(spacing: 24) {
            VideoCard(video: Video.samples[1], zoomNamespace: namespace)
            SkeletonCard()
        }
        .padding()
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
