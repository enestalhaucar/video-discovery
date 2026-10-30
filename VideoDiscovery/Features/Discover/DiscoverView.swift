import SwiftUI

// Placeholder until the designed Discover feed lands.
struct DiscoverView: View {
    var body: some View {
        List(Video.samples) { video in
            NavigationLink(video.title, value: video)
        }
        .navigationTitle("Discover")
    }
}

#Preview {
    NavigationStack {
        DiscoverView()
    }
}
