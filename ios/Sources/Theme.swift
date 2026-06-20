import SwiftUI
import UIKit

extension Color {
    /// A color that adapts to light / dark appearance.
    static func dyn(_ light: Color, _ dark: Color) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}

enum Theme {
    // Energy-product palette. Dark by default feel; light variant mirrors it.
    static let bg       = Color.dyn(Color(red: 0.95, green: 0.96, blue: 0.95), Color(red: 0.059, green: 0.082, blue: 0.071))
    static let card     = Color.dyn(.white,                                     Color(red: 0.098, green: 0.133, blue: 0.118))
    static let ink      = Color.dyn(Color(red: 0.08, green: 0.13, blue: 0.10),  Color(red: 0.95, green: 0.94, blue: 0.91))
    static let subtle   = Color.dyn(Color(red: 0.37, green: 0.42, blue: 0.39),  Color(red: 0.58, green: 0.63, blue: 0.60))
    static let hairline = Color.dyn(Color(red: 0.88, green: 0.90, blue: 0.88),  Color(red: 0.16, green: 0.21, blue: 0.18))

    static let green     = Color.dyn(Color(red: 0.05, green: 0.43, blue: 0.33), Color(red: 0.22, green: 0.83, blue: 0.60))
    static let greenDeep = Color.dyn(Color(red: 0.04, green: 0.34, blue: 0.27), Color(red: 0.16, green: 0.66, blue: 0.48))
    static let greenSoft = Color.dyn(Color(red: 0.89, green: 0.95, blue: 0.92), Color(red: 0.08, green: 0.16, blue: 0.13))
    static let amber     = Color.dyn(Color(red: 0.72, green: 0.46, blue: 0.06), Color(red: 0.96, green: 0.70, blue: 0.24))
    static let amberSoft = Color.dyn(Color(red: 0.98, green: 0.93, blue: 0.82), Color(red: 0.16, green: 0.13, blue: 0.06))
    static let red       = Color.dyn(Color(red: 0.76, green: 0.23, blue: 0.18), Color(red: 1.0, green: 0.46, blue: 0.40))
    static let redSoft   = Color.dyn(Color(red: 0.98, green: 0.90, blue: 0.88), Color(red: 0.18, green: 0.10, blue: 0.09))
    static let grid      = Color.dyn(Color(red: 0.18, green: 0.44, blue: 0.88), Color(red: 0.36, green: 0.59, blue: 1.0))

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
    /// Card surface with a hairline + gentle shadow.
    func cardSurface(_ radius: CGFloat = 18) -> some View {
        self.background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.06), radius: 7, y: 3)
    }
    /// App background; follows the device appearance (dark/light).
    func warmScreen() -> some View {
        self.background(Theme.bg.ignoresSafeArea())
    }
}
