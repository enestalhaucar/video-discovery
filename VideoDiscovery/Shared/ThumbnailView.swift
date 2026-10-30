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
                    AsyncImage(url: url, transaction: Transaction(animation: Motion.contentFade)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .transition(.opacity)
                        case .failure:
                            placeholder
                        default:
                            Color.clear
                        }
                    }
                } else {
                    placeholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "film")
            .font(.title)
            .foregroundStyle(Theme.labelSecondary)
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
