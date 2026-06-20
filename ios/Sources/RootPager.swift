import SwiftUI

/// Two start screens — Home and Plan-my-day — paged horizontally, sharing one clock.
struct RootPager: View {
    @StateObject private var clock = ClockStore()

    var body: some View {
        // A horizontal paging ScrollView (not a `.page` TabView, whose UIPageViewController
        // swallows the top safe-area inset and slides content under the Dynamic Island).
        // geo RESPECTS the safe area, so geo.safeAreaInsets read the true device insets and
        // geo.size is the safe height. The ScrollView itself extends under the bars, so we
        // re-inset its content by exactly those insets: headers clear the Dynamic Island and
        // the ask bar clears the home indicator, with each page sized to the safe height.
        GeometryReader { geo in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    HomeView(clock: clock).frame(width: geo.size.width, height: geo.size.height)
                    PlanDayView(clock: clock).frame(width: geo.size.width, height: geo.size.height)
                }
                .scrollTargetLayout()
                .padding(.top, geo.safeAreaInsets.top)
                .padding(.bottom, geo.safeAreaInsets.bottom)
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
        }
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
