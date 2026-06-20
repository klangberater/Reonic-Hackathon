import SwiftUI

enum Theme {
    static let green = Color(red: 0.12, green: 0.66, blue: 0.49)
    static let greenDeep = Color(red: 0.05, green: 0.42, blue: 0.34)
    static let amber = Color(red: 0.90, green: 0.62, blue: 0.15)
    static let red = Color(red: 0.84, green: 0.33, blue: 0.30)
    static let grid = Color(red: 0.30, green: 0.45, blue: 0.95)
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.14)
    static let subtle = Color(red: 0.45, green: 0.49, blue: 0.52)
    static let card = Color(.secondarySystemBackground)
    static let bg = Color(.systemBackground)

    /// free / partial / paid → the source color used on tiles, ribbon, sheet.
    static func source(_ s: String) -> Color {
        switch Source(s) {
        case .free: return green
        case .partial: return amber
        case .paid: return red
        }
    }
    static func sourceLabel(_ s: String) -> String {
        switch Source(s) { case .free: return "free"; case .partial: return "partial"; case .paid: return "paid" }
    }

    static func statusGradient(_ status: String) -> LinearGradient {
        let colors: [Color]
        switch status {
        case "exporting_surplus": colors = [green, greenDeep]
        case "drawing_grid": colors = [grid, Color(red: 0.18, green: 0.28, blue: 0.62)]
        default: colors = [Color(red: 0.35, green: 0.55, blue: 0.55), greenDeep]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
