import SwiftUI

/// Two start screens — Home and Plan-my-day — paged horizontally, sharing one clock.
struct RootPager: View {
    @StateObject private var clock = ClockStore()
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            HomeView(clock: clock).tag(0)
            PlanDayView(clock: clock).tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.keyboard)
    }
}

/// A tiny two-dot affordance each screen shows in its header to hint horizontal swipe.
struct PagerDots: View {
    let current: Int   // 0 = Home, 1 = Plan
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { i in
                Circle().fill(i == current ? Theme.ink : Theme.hairline).frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}
