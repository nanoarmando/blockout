import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(nsColor: NSColor(hex: hex, alpha: opacity))
    }

    /// A color that follows the system appearance.
    static func dynamic(light: UInt32, dark: UInt32, lightOpacity: Double = 1, darkOpacity: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(hex: dark, alpha: darkOpacity)
                : NSColor(hex: light, alpha: lightOpacity)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// App colors from the approved mockup, light and dark.
enum Theme {
    static let background = Color.dynamic(light: 0xF6F5F1, dark: 0x161615)
    static let surface = Color.dynamic(light: 0xFBFAF7, dark: 0x1C1C1A)
    static let sidebar = Color.dynamic(light: 0xEFEDE7, dark: 0x121211)
    static let card = Color.dynamic(light: 0xFFFFFF, dark: 0x232321)
    static let ink = Color.dynamic(light: 0x1D1D1B, dark: 0xEDECE8)
    static let muted = Color.dynamic(light: 0x5E5C57, dark: 0xA3A09A)
    static let secondary = Color.dynamic(light: 0x3F3D39, dark: 0xC9C6BF)
    static let line = Color.dynamic(light: 0xE2DFD7, dark: 0x33322F)
    static let lineSoft = Color.dynamic(light: 0xEEECE6, dark: 0x3A3936)
    static let stripe = Color.dynamic(light: 0xF0EEE8, dark: 0x2D2C2A)
    static let control = Color.dynamic(light: 0xDAD6CC, dark: 0x3A3936)
    static let dashed = Color.dynamic(light: 0xA8A398, dark: 0x6E6B65)
    static let check = Color(hex: 0x8C887F)
    static let barOff = Color.dynamic(light: 0xD3CFC5, dark: 0x4A4844)
    static let accent = Color.dynamic(light: 0x0F766E, dark: 0x2F6FE4)
    static let accentText = Color.dynamic(light: 0x9A3F07, dark: 0x8AB4FF)
    static let danger = Color.dynamic(light: 0xB42318, dark: 0xFF7B6E)
    static let strong = Color.dynamic(light: 0x1D1D1B, dark: 0xEDECE8)
    static let onStrong = Color.dynamic(light: 0xFFFFFF, dark: 0x1D1D1B)
    static let outside = Color.dynamic(light: 0xFAF9F6, dark: 0x1A1A18)
    static let now = Color.dynamic(light: 0xD92D20, dark: 0xFF5A5F)
    static let nowSoft = Color.dynamic(light: 0xD92D20, dark: 0xFF5A5F, lightOpacity: 0.3, darkOpacity: 0.35)
    static let urgentHigh = Color(hex: 0xB42318)
    static let ok = Color.dynamic(light: 0x2F7D4F, dark: 0x4CC27A)
    static let banner = Color.dynamic(light: 0xFFFBF6, dark: 0x2F6FE4, lightOpacity: 1, darkOpacity: 0.08)
}

/// Eight project colors assigned in rotation. Light: dark text on a tint; dark: tinted dark fill with light text.
enum ProjectPalette {
    private static let colors: [(text: UInt32, tint: UInt32)] = [
        (0x0F5F59, 0xD5EFEC),
        (0x3F6212, 0xE3EED3),
        (0x9A3412, 0xF9E1D3),
        (0x3730A3, 0xE0E0F7),
        (0x1D4ED8, 0xDCE6FB),
        (0x9F1239, 0xF7DDE3),
        (0x854D0E, 0xF5EBC8),
        (0x6B21A8, 0xEEDFF7),
    ]
    private static let neutral: (text: UInt32, tint: UInt32) = (0x3F3D39, 0xECEAE4)
    private static let darkBase: UInt32 = 0x161615

    static var count: Int { colors.count }

    static func foreground(_ index: Int?) -> Color {
        let pair = pair(index)
        return .dynamic(light: pair.text, dark: pair.tint)
    }

    static func fill(_ index: Int?) -> Color {
        let pair = pair(index)
        return .dynamic(light: pair.tint, dark: mix(pair.text, darkBase, weight: 0.55))
    }

    private static func pair(_ index: Int?) -> (text: UInt32, tint: UInt32) {
        guard let index else { return neutral }
        return colors[((index % colors.count) + colors.count) % colors.count]
    }

    private static func mix(_ first: UInt32, _ second: UInt32, weight: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let a = Double((first >> shift) & 0xFF), b = Double((second >> shift) & 0xFF)
            return UInt32((a * weight + b * (1 - weight)).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }
}
