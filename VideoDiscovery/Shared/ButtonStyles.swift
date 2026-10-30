import SwiftUI

/// Icon-only buttons dim while pressed.
struct PressedOpacityStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? Theme.Opacity.pressed : 1)
    }
}

/// Scales down while pressed. Under Reduce Motion it dims instead.
struct PressedScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed && reduceMotion ? Theme.Opacity.pressed : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
