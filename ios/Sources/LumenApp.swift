import SwiftUI

@main
struct LumenApp: App {
    @AppStorage("appearance") private var appearance = "dark"   // dark energy look by default

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(appearance == "light" ? .light : .dark)
        }
    }
}
