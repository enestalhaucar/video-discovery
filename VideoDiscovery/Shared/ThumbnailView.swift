import SwiftUI

/// 16:9 artwork, filled and cropped, with a film placeholder for a missing or failed image.
struct ThumbnailView: View {
    let url: URL?
    var cornerRadius: CGFloat = Theme.Radius.card

    var body: some View {
        Theme.surfaceTint
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if let url {
                    CachedImage(url: url)
                        .id(url)
                } else {
                    FilmPlaceholder()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

private struct FilmPlaceholder: View {
    var body: some View {
        Image(systemName: "film")
            .font(.title)
            .foregroundStyle(Theme.labelSecondary)
    }
}

/// Shows an image from the session cache at once, or loads it and fades it in.
private struct CachedImage: View {
    let url: URL
    @State private var image: UIImage?
    @State private var failed = false

    init(url: URL) {
        self.url = url
        _image = State(initialValue: MediaCache.shared.cachedImage(for: url))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else if failed {
                FilmPlaceholder()
            } else {
                Color.clear
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard image == nil else { return }
        do {
            let loaded = try await MediaCache.shared.image(for: url)
            withAnimation(Motion.contentFade) {
                image = loaded
            }
        } catch {
            // A cancelled load (the view went away) says nothing about this image.
            guard !Task.isCancelled else { return }
            failed = true
        }
    }
}

#Preview {
    VStack {
        ThumbnailView(url: Video.samples[1].thumbnailURL)
        ThumbnailView(url: nil, cornerRadius: Theme.Radius.compact)
            .frame(width: Theme.Size.rowThumbWidth)
    }
    .padding()
}
