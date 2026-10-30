import SwiftUI

struct CategoryTag: View {
    let category: String

    var body: some View {
        Text(category)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.tint.opacity(0.12), in: Capsule())
            .accessibilityLabel("Category: \(category)")
    }
}

#Preview {
    CategoryTag(category: "Animation")
}
