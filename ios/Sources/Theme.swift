import SwiftUI

enum Theme {
    // Warm, friendly light palette
    static let bg = Color(red: 0.98, green: 0.96, blue: 0.91)        // warm cream
    static let card = Color(red: 1.0, green: 0.995, blue: 0.98)      // warm white
    static let ink = Color(red: 0.17, green: 0.15, blue: 0.12)       // warm near-black
    static let subtle = Color(red: 0.52, green: 0.49, blue: 0.44)    // warm gray
    static let hairline = Color(red: 0.84, green: 0.80, blue: 0.73)  // warm border

    static let green = Color(red: 0.16, green: 0.62, blue: 0.46)
    static let greenDeep = Color(red: 0.06, green: 0.40, blue: 0.32)
    static let greenSoft = Color(red: 0.89, green: 0.94, blue: 0.89)
    static let amber = Color(red: 0.91, green: 0.64, blue: 0.20)
    static let amberSoft = Color(red: 0.99, green: 0.93, blue: 0.80)
    static let red = Color(red: 0.80, green: 0.36, blue: 0.30)
    static let redSoft = Color(red: 0.98, green: 0.90, blue: 0.86)
    static let grid = Color(red: 0.35, green: 0.49, blue: 0.86)

    static func source(_ s: String) -> Color {
        switch Source(s) { case .free: return green; case .partial: return amber; case .paid: return red }
    }
    static func sourceSoft(_ s: String) -> Color {
        switch Source(s) { case .free: return greenSoft; case .partial: return amberSoft; case .paid: return redSoft }
    }
    static func sourceLabel(_ s: String) -> String {
        switch Source(s) { case .free: return "free"; case .partial: return "partial"; case .paid: return "paid" }
    }
}

extension View {
    /// Cozy warm-white card surface with a soft hairline + gentle shadow.
    func cardSurface(_ radius: CGFloat = 20) -> some View {
        self.background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
    }
    /// Apply the warm, friendly look (rounded type, cream bg, light scheme) to a screen root.
    func warmScreen() -> some View {
        self.fontDesign(.rounded)
            .background(Theme.bg.ignoresSafeArea())
            .preferredColorScheme(.light)
    }
}
