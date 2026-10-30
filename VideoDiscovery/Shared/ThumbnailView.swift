import SwiftUI

/// 16:9 artwork with a film placeholder for a missing or failed image.
struct ThumbnailView: View {
    let url: URL?
    var cornerRadius: CGFloat = 16

    var body: some View {
        Rectangle()
            .fill(.quaternary)
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
            .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "film")
            .font(.title)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack {
        ThumbnailView(url: Video.samples[1].thumbnailURL)
        ThumbnailView(url: nil)
    }
    .padding()
}
