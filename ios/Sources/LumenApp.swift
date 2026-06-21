import SwiftUI

@main
struct LumenApp: App {
    @AppStorage("appearance") private var appearance = "dark"

    init() { NotificationManager.configure() }

    var body: some Scene {
        WindowGroup {
            RootPager()
                .preferredColorScheme(appearance == "light" ? .light : .dark)
        }
    }
}
