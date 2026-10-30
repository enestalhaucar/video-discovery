import SwiftUI

/// The Discover feed card: 16:9 artwork, floating heart, then title and category.
/// The heart sits beside the link, not inside it, so tapping it never navigates.
struct VideoCard: View {
    let video: Video
    let zoomNamespace: Namespace.ID

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: video) {
                VStack(alignment: .leading, spacing: Theme.Space.pt10) {
                    ThumbnailView(url: video.thumbnailURL)
                        .zoomSource(id: video.id, in: zoomNamespace)
                    VStack(alignment: .leading, spacing: Theme.Space.pt8) {
                        Text(video.title)
                            .font(.headline)
                            .foregroundStyle(Theme.label)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        CategoryTag(category: video.category)
                    }
                    .accessibilityElement(children: .combine)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PressableCardStyle())

            FavoriteButton(video: video, style: .float)
                .padding(Theme.Space.pt4)
        }
    }
}

/// Shrinks the card slightly while it's pressed and springs back on release.
private struct PressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1, anchor: UnitPoint(x: 0.5, y: 0.4))
            .animation(configuration.isPressed ? Motion.press : Motion.release, value: configuration.isPressed)
    }
}

/// Grey blocks in the shape of a card, shown three at a time while the catalogue loads.
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.pt10) {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .aspectRatio(16 / 9, contentMode: .fit)
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .frame(width: proxy.size.width * 0.62)
            }
            .frame(height: 18)
            Capsule()
                .frame(width: 76, height: 28)
        }
        .foregroundStyle(Theme.skeleton)
        .shimmering()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

#Preview {
    @Previewable @Namespace var namespace
    NavigationStack {
        VStack(spacing: Theme.Space.pt20) {
            VideoCard(video: Video.samples[1], zoomNamespace: namespace)
            SkeletonCard()
        }
        .padding()
    }
    .environment(FavoritesStore(persistence: FileFavoritesPersistence()))
}
