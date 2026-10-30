import SwiftUI

struct VideoDetailView: View {
    let video: Video

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(video.title)
                    .font(.title2.bold())
                Text(video.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(video.description)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        VideoDetailView(video: Video.samples[1])
    }
}
