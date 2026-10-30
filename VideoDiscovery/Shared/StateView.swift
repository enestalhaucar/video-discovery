import SwiftUI

/// Centred empty, error and no-results states, with at most one bordered action.
struct StateView: View {
    let symbol: String
    let title: String
    var message: String?
    var actionTitle: String?
    var isLoading = false
    /// Pulses the symbol once when the view appears.
    var pulses = false
    var action: () -> Void = {}

    @State private var pulseCount = 0

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 48))
                .foregroundStyle(Theme.labelSecondary)
                .symbolEffect(.bounce, value: pulseCount)
                .padding(.bottom, Theme.Space.pt16)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.label)
                .padding(.bottom, Theme.Space.pt4)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.labelSecondary)
                    .frame(maxWidth: 280)
            }
            if let actionTitle {
                Button(action: action) {
                    ZStack {
                        Text(actionTitle)
                            .opacity(isLoading ? 0 : 1)
                        if isLoading {
                            ProgressView()
                                .tint(Theme.accentInk)
                        }
                    }
                    .animation(Motion.crossfade, value: isLoading)
                }
                .buttonStyle(OutlinedCapsuleButtonStyle())
                .disabled(isLoading)
                .padding(.top, Theme.Space.pt24)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 48)
        .padding(.horizontal, Theme.Space.pt32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if pulses { pulseCount += 1 }
        }
    }
}

/// The bordered capsule button used for "Try again" and "Browse videos".
struct OutlinedCapsuleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.accentInk)
            .padding(.horizontal, 20)
            .frame(minWidth: 120, minHeight: Theme.Size.hit)
            .background(configuration.isPressed ? Theme.accentSoft : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.accentInk, lineWidth: 1.5))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

#Preview {
    StateView(
        symbol: "wifi.exclamationmark",
        title: "Couldn’t load videos",
        message: "Check your connection and try again.",
        actionTitle: "Try again"
    )
}
