import SwiftUI

enum CloudwardColors {
    static let inkBlue = Color(light: 0x2B3A4A, dark: 0xC9D6E3)
    static let celadon = Color(light: 0x7FA38F, dark: 0x8FB8A3)
    static let moonWhite = Color(light: 0xF5F4EF, dark: 0x1C1E21)
    static let cloudGray = Color(light: 0xAEB6BD, dark: 0x6B7480)
    static let amber = Color(light: 0xC98A2D, dark: 0xD9A85C)
    static let vermilionMist = Color(light: 0xB85C50, dark: 0xC97A6E)
    static let card = Color(light: 0xFFFFFF, dark: 0x26292D)
    static let panel = Color(light: 0xF8F7F2, dark: 0x1F2226)
    static let separator = Color(light: 0xE6E3DC, dark: 0x34383D)
    static let rowHover = celadon.opacity(0.08)
    static let selectedRow = celadon.opacity(0.12)
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(hex: bestMatch == .darkAqua ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
