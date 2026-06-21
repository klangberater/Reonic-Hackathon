import SwiftUI

/// Lightweight settings sheet: the demo clock (summer/winter) and appearance.
/// Bound to the shared `ClockStore` so both Home and Plan-my-day can present it.
struct SettingsView: View {
    @ObservedObject var clock: ClockStore
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("briefingOn") private var briefingOn = true
    @AppStorage("briefingHour") private var briefingHour = 7
    @AppStorage("briefingMinute") private var briefingMinute = 0
    @AppStorage("briefingSmart") private var briefingSmart = true
    @Environment(\.dismiss) private var dismiss
    @State private var contract: Contract?
    @State private var money: Money?
    @State private var energy: EnergyState?
    @State private var insights: Insights?

    var body: some View {
        NavigationStack {
            Form {
                if let c = contract { contractSection(c) }

                Section {
                    Picker("Time", selection: Binding(
                        get: { clock.clock },
                        set: { clock.setClock($0) }
                    )) {
                        ForEach(DemoClock.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Demo clock")
                } footer: {
                    Text("Switches the home's “now”. Live tracks the real clock; Sunny demo pins a bright midday so plans land on solar; Winter surfaces the heat-pump anomaly.")
                }

                briefingSection

                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task(id: clock.clock) {
                let api = APIClient()
                contract = try? await api.contract(clock: clock.clock)
                money = try? await api.money(clock: clock.clock)
                energy = try? await api.state(clock: clock.clock)
                insights = try? await api.insights(clock: clock.clock)
                reschedule(on: briefingOn)   // refresh the scheduled briefing with today's facts
            }
            .onAppear { reschedule(on: briefingOn) }
            .onChange(of: briefingOn) { _, on in reschedule(on: on) }
            .onChange(of: briefingHour) { _, _ in reschedule(on: briefingOn) }
            .onChange(of: briefingMinute) { _, _ in reschedule(on: briefingOn) }
        }
    }

    // MARK: - Morning briefing

    // A proactive 7am briefing: the facts the user needs to plan their day — solar outlook,
    // price, battery, cheapest window, projected earnings, and anything that needs attention.
    // Configurable time + on/off; "smart" keeps it quiet on dull days. Preview fires it now.
    @ViewBuilder private var briefingSection: some View {
        Section {
            Toggle("Morning briefing", isOn: $briefingOn)
            if briefingOn {
                DatePicker("Send at", selection: briefingTime, displayedComponents: .hourAndMinute)
                Toggle("Only when it's worth it", isOn: $briefingSmart)
                Button {
                    NotificationManager.previewBriefing(title: briefingTitle, body: briefingBody, route: briefingRoute)
                } label: {
                    Label("Preview now", systemImage: "bell.badge")
                }
            }
        } header: {
            Text("Daily briefing")
        } footer: {
            Text(briefingOn
                 ? "Your day's energy at a glance — sun, prices, battery, earnings, and anything to act on — at \(timeString). "
                   + (briefingSmart ? "Only on a good solar day or when something needs attention." : "Every day.")
                 : "Turn on a morning briefing of the day's energy outlook.")
        }
    }

    private var briefingTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: briefingHour, minute: briefingMinute, second: 0, of: Date()) ?? Date() },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                briefingHour = c.hour ?? 7; briefingMinute = c.minute ?? 0
            }
        )
    }

    private var timeString: String { String(format: "%02d:%02d", briefingHour, briefingMinute) }

    private func reschedule(on: Bool) {
        guard on else { NotificationManager.cancelMorningBriefing(); return }
        NotificationManager.scheduleMorningBriefing(hour: briefingHour, minute: briefingMinute,
                                                    title: briefingTitle, body: briefingBody, route: briefingRoute)
    }

    // The most important alert (e.g. the heat-pump fault), if any.
    private var anomaly: InsightEvent? {
        insights?.events.first { $0.active && $0.type == "anomaly" && $0.severity == "high" }
    }
    // The cheapest-window nudge ("Cheapest power is around 13:00") — the headline planning fact.
    private var cheapestNudge: InsightEvent? {
        insights?.events.first { $0.active && $0.type == "nudge" }
    }

    // Tapping the briefing opens the visual briefing popup.
    private var briefingRoute: String { "briefing" }

    private var briefingTitle: String {
        anomaly != nil ? "Good morning — one thing to check" : "Good morning — today’s energy briefing"
    }

    /// The briefing body: assembled from live data so it stands alone — the user can plan their
    /// day from the notification without opening the app.
    private var briefingBody: String {
        var parts: [String] = []

        // Lead with anything that needs action.
        if let a = anomaly { parts.append("Heads up: \(a.title). \(a.suggestedAction)") }

        // Solar outlook + the two numbers that decide when to run things.
        if let s = energy {
            parts.append(solarLine(s))
            parts.append("Grid €\(String(format: "%.2f", s.priceEurPerKwh))/kWh, battery \(Int(s.battery.socPct.rounded()))%.")
        }

        // The cheapest window — the single most useful planning fact.
        if let n = cheapestNudge { parts.append("\(n.title).") }

        // Projected money made today selling surplus back.
        parts.append(madeTodayLine)

        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func solarLine(_ s: EnergyState) -> String {
        switch s.status {
        case "exporting_surplus": return "Strong sun today — you're powering the house and exporting the surplus."
        case "drawing_grid":      return "Low solar this morning — you're topping up from the grid."
        default:                  return "Your solar is covering the house right now."
        }
    }

    // Projected money made today by selling solar surplus back — a per-day run-rate from the
    // month-to-date solar earnings. The API's `earning` flag means net-positive overall (not
    // "earned from solar"), so gate on the solar earnings themselves. Empty in winter (€0).
    private var madeTodayLine: String {
        guard let m = money, m.daysElapsed > 0 else { return "" }
        let perDay = m.earnedFromSolarEur / Double(m.daysElapsed)
        guard perDay >= 0.01 else { return "" }
        return "On track to earn about €\(String(format: "%.2f", perDay)) selling solar back today."
    }

    // The contract surfaced for the customer: tariff, renewal deadline, feed-in (the lever
    // behind "money earned"), and the full terms — fields the rest of the app doesn't use.
    @ViewBuilder private func contractSection(_ c: Contract) -> some View {
        Section {
            LabeledContent("Tariff", value: c.tariffName)
            LabeledContent("Term ends", value: prettyDate(c.contractEnd))
            LabeledContent("Give notice by", value: prettyDate(c.noticeByDate))
            LabeledContent("Feed-in", value: String(format: "€%.3f / kWh", c.feedInEurPerKwh))
            LabeledContent("Monthly fee", value: String(format: "€%.2f", c.baseFeeEurPerMonth))
            DisclosureGroup("Full terms") {
                Text(c.termsText).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Your contract")
        } footer: {
            Text(c.inNoticeWindow
                 ? "You're inside the \(c.noticePeriodWeeks)-week notice window — give notice by \(prettyDate(c.noticeByDate)) or it auto-renews for \(c.autoRenewMonths) months."
                 : "Auto-renews for \(c.autoRenewMonths) months unless you give notice — \(c.daysUntilNoticeDeadline) days until the deadline.")
        }
    }

    private func prettyDate(_ ymd: String) -> String {
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"; inF.locale = Locale(identifier: "en_US_POSIX")
        guard let d = inF.date(from: ymd) else { return ymd }
        let outF = DateFormatter(); outF.dateFormat = "d MMM yyyy"; outF.locale = Locale(identifier: "en_US_POSIX")
        return outF.string(from: d)
    }
}
