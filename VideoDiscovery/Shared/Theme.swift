import SwiftUI
import UIKit

/// Design tokens from the Quiet Cinema design system.
enum Theme {
    // MARK: Colour

    static let background = Color(light: 0xF2F2F7, dark: 0x000000)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let surfaceTint = Color(light: 0xE5E5EA, dark: 0x2C2C2E)
    static let skeleton = surfaceTint
    static let skeletonSheen = Color(light: UIColor(white: 1, alpha: 0.65), dark: UIColor(white: 1, alpha: 0.07))
    static let fillSearch = Color(
        light: UIColor(rgb: 0x767680, alpha: 0.12),
        dark: UIColor(rgb: 0x767680, alpha: 0.24)
    )
    static let label = Color(light: 0x000000, dark: 0xFFFFFF)
    static let labelSecondary = Color(
        light: UIColor(rgb: 0x3C3C43, alpha: 0.76),
        dark: UIColor(rgb: 0xEBEBF5, alpha: 0.6)
    )
    static let hairline = Color(light: UIColor(white: 0, alpha: 0.08), dark: .clear)

    /// The one warm accent; it also means "favourite". For fills and symbols.
    static let accent = Color(light: 0xE11D48, dark: 0xFB7185)
    /// The accent as text (back button, bordered buttons), for 4.5:1 on light grounds.
    static let accentInk = Color(light: 0xBE123C, dark: 0xFB7185)
    static let accentSoft = Color(
        light: UIColor(rgb: 0xE11D48, alpha: 0.12),
        dark: UIColor(rgb: 0xFB7185, alpha: 0.16)
    )
    /// Glyphs on an accent fill.
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x000000)

    static let stage = Color.black
    static let onStage = Color.white
    static let onStageSecondary = Color.white.opacity(0.7)
    static let stageMaterial = Color(uiColor: UIColor(rgb: 0x28282C, alpha: 0.55))

    static let error = Color(light: 0xFF3B30, dark: 0xFF453A)
    static let destructiveFill = Color(uiColor: UIColor(rgb: 0xD70015))

    /// Text and fill colours for a category chip.
    static func chipColors(for category: String) -> (text: Color, fill: Color) {
        switch category {
        case "Animation":
            (Color(light: 0x6D28D9, dark: 0xA78BFA), Color(uiColor: UIColor(rgb: 0x8B5CF6, alpha: 0.14)))
        case "City":
            (Color(light: 0x1D4ED8, dark: 0x60A5FA), Color(uiColor: UIColor(rgb: 0x2563EB, alpha: 0.14)))
        case "Travel":
            (Color(light: 0x0F6B64, dark: 0x2DD4BF), Color(uiColor: UIColor(rgb: 0x0D9488, alpha: 0.14)))
        case "Highlights":
            (Color(light: 0xB23A0A, dark: 0xFB923C), Color(uiColor: UIColor(rgb: 0xEA580C, alpha: 0.14)))
        default:
            (Color(light: 0x4B5563, dark: 0x9CA3AF), Color(uiColor: UIColor(rgb: 0x6B7280, alpha: 0.14)))
        }
    }

    // MARK: Space, shape, size

    enum Space {
        static let pt4: CGFloat = 4
        static let pt8: CGFloat = 8
        static let pt10: CGFloat = 10
        static let pt12: CGFloat = 12
        static let pt16: CGFloat = 16
        static let pt20: CGFloat = 20
        static let pt24: CGFloat = 24
        static let pt32: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 16
        static let compact: CGFloat = 10
    }

    enum Size {
        static let hit: CGFloat = 44
        static let heart: CGFloat = 36
        static let play: CGFloat = 56
        static let overlayPlay: CGFloat = 64
        static let track: CGFloat = 4
        static let thumb: CGFloat = 14
        static let thumbDrag: CGFloat = 22
        static let rowThumbWidth: CGFloat = 112
    }

    enum Opacity {
        static let dimmed = 0.4
        static let pressed = 0.55
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(light: UIColor(rgb: light), dark: UIColor(rgb: dark))
    }

    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }
}
