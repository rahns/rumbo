import RumboCore
import SwiftUI
import UIKit

/// Color tokens from docs/03-experience.md §3.2. Each has a light and a dark value.
enum Palette {
    static let coral = dynamic(light: 0xF25C4A, dark: 0xFF6E5C)
    static let ink = dynamic(light: 0x1E2A4A, dark: 0xE9ECF7)
    static let sun = dynamic(light: 0xFFBE1A, dark: 0xFFC83D)
    static let leaf = dynamic(light: 0x5BC236, dark: 0x6BD144)
    static let sky = dynamic(light: 0x2FA6EE, dark: 0x4DB5F5)
    static let lilac = dynamic(light: 0xDEE4FF, dark: 0x2A3560)
    static let cream = dynamic(light: 0xFFF3D6, dark: 0x3A3320)

    /// App background: soft off-white by day, Dreaming-style navy by night.
    static let background = dynamic(light: 0xF7F8FC, dark: 0x141B30)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x1E2A4A)
    static let cardEdge = dynamic(light: 0xE3E6F0, dark: 0x0F1526)
    static let secondaryText = dynamic(light: 0x5D6C7B, dark: 0xA8B1C9)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// A darker shade for the bottom edge of chunky buttons and cards.
    func edge(_ amount: CGFloat = 0.22) -> Color {
        Color(uiColor: UIColor { traits in
            let base = UIColor(self).resolvedColor(with: traits)
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            return UIColor(hue: hue, saturation: min(1, saturation * 1.05), brightness: max(0, brightness - amount), alpha: alpha)
        })
    }
}

extension Strand {
    /// Strand accents: input = coral, output = sky, language-focused = leaf, fluency = sun.
    var color: Color {
        switch self {
        case .input: Palette.coral
        case .output: Palette.sky
        case .languageFocused: Palette.leaf
        case .fluency: Palette.sun
        }
    }

    var label: String {
        switch self {
        case .input: "Listen"
        case .output: "Produce"
        case .languageFocused: "Learn"
        case .fluency: "Flow"
        }
    }
}

extension Font {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}
