import SwiftUI

enum MochiColorKey: String, Codable, CaseIterable {
    case blue
    case pink
    case green
    case purple
    case amber

    static var random: MochiColorKey {
        allCases.randomElement() ?? .blue
    }
}

struct MochiTheme {
    let r: Double
    let g: Double
    let b: Double
    let dark: Color
    let gradientDark: Color
    let accent: Color

    /// The full-strength theme background color
    var background: Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }

    /// Theme color at a given opacity (for inner fill, shadows, etc.)
    func color(opacity: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255).opacity(opacity)
    }

    static let themes: [MochiColorKey: MochiTheme] = [
        .blue: MochiTheme(
            r: 217, g: 235, b: 255,
            dark: Color(hex: "7faadc"),
            gradientDark: Color(hex: "b8d8fb"),
            accent: Color(hex: "3b82f6")
        ),
        .pink: MochiTheme(
            r: 255, g: 217, b: 224,
            dark: Color(hex: "e08ca0"),
            gradientDark: Color(hex: "ffc2cf"),
            accent: Color(hex: "f43f5e")
        ),
        .green: MochiTheme(
            r: 217, g: 242, b: 224,
            dark: Color(hex: "82c496"),
            gradientDark: Color(hex: "b8e6c7"),
            accent: Color(hex: "10b981")
        ),
        .purple: MochiTheme(
            r: 235, g: 217, b: 255,
            dark: Color(hex: "b392e0"),
            gradientDark: Color(hex: "d6b8fa"),
            accent: Color(hex: "8b5cf6")
        ),
        .amber: MochiTheme(
            r: 255, g: 236, b: 217,
            dark: Color(hex: "e0b38c"),
            gradientDark: Color(hex: "fce3cc"),
            accent: Color(hex: "f59e0b")
        ),
    ]

    static func forKey(_ key: MochiColorKey) -> MochiTheme {
        themes[key] ?? themes[.blue]!
    }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
