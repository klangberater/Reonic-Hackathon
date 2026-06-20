import SwiftUI

@main
struct LumenApp: App {
    @AppStorage("appearance") private var appearance = "dark"

    var body: some Scene {
        WindowGroup {
            RootPager()
                .preferredColorScheme(appearance == "light" ? .light : .dark)
        }
    }
}
