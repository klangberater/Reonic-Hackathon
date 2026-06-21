import SwiftUI

/// The app's single start screen: Plan-my-day. (The Home energy-glance screen still lives in
/// HomeView.swift but is intentionally not shown — reachable again by paging it back in here.)
struct RootPager: View {
    @StateObject private var clock = ClockStore()

    var body: some View {
        PlanDayView(clock: clock)
            .background(Theme.bg.ignoresSafeArea())
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
