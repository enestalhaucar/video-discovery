import SwiftUI

/// The search field under the large title, styled like the system one.
///
/// On iOS 26 and later an always-visible system search drawer collapses the large title, so the
/// field lives in the content to keep the designed layout on every iOS version.
struct SearchField: View {
    @Binding var text: String
    var prompt = "Search videos"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.labelSecondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(Theme.labelSecondary))
                .foregroundStyle(Theme.label)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(Theme.labelSecondary)
                .frame(width: 28, height: 28)
                .buttonStyle(PressedOpacityStyle())
            }
        }
        .padding(.horizontal, Theme.Space.pt8)
        .frame(height: 36)
        .background(Theme.fillSearch, in: RoundedRectangle(cornerRadius: Theme.Radius.compact, style: .continuous))
    }
}

#Preview {
    @Previewable @State var text = "park"
    SearchField(text: $text)
        .padding()
}
