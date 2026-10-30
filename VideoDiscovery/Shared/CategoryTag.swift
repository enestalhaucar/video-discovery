import SwiftUI

/// The category capsule under every title, in the category's own colour.
struct CategoryTag: View {
    let category: String

    var body: some View {
        let colors = Theme.chipColors(for: category)
        Text(category)
            .font(.caption.weight(.semibold))
            .foregroundStyle(colors.text)
            .lineLimit(1)
            .fixedSize()
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(colors.fill, in: Capsule())
            .accessibilityLabel("Category: \(category)")
    }
}

#Preview {
    VStack(alignment: .leading) {
        ForEach(["Animation", "City", "Travel", "Highlights", "Other"], id: \.self) {
            CategoryTag(category: $0)
        }
    }
    .padding()
}
