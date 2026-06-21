import SwiftUI
import Charts

/// The morning briefing popup: everything the user needs to plan their day, shown as Schaubilder —
/// expected solar output, cheapest hours to charge, the price/battery/earnings right now, and any
/// alert. Opened when the daily-briefing notification is tapped.
struct BriefingView: View {
    let clock: DemoClock
    var onPlan: () -> Void = {}
    var onAsk: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var energy: EnergyState?
    @State private var money: Money?
    @State private var insights: Insights?
    @State private var curve: [PlanResult.CurvePoint] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(greeting).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    if loading && energy == nil {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        statGrid
                        if let a = anomaly { anomalyCard(a) }
                        solarCard
                        planButton
                    }
                }
                .padding(20)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Morning briefing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
    }

    // MARK: data

    private func load() async {
        let api = APIClient()
        async let s = try? await api.state(clock: clock)
        async let m = try? await api.money(clock: clock)
        async let i = try? await api.insights(clock: clock)
        async let p = try? await api.planDay(tasks: [PlanTaskInput(device: "ev", deadline: nil, target: 80, start: nil)], mode: .cheapest, clock: clock)
        energy = await s; money = await m; insights = await i
        curve = (await p)?.curve ?? []
        loading = false
    }

    private var anomaly: InsightEvent? {
        insights?.events.first { $0.active && $0.type == "anomaly" && $0.severity == "high" }
    }
    private var greeting: String {
        anomaly != nil ? "Good morning — one thing to check" : "Good morning — here’s your day"
    }
    private var earnedToday: Double? {
        guard let m = money, m.daysElapsed > 0 else { return nil }
        let v = m.earnedFromSolarEur / Double(m.daysElapsed)
        return v >= 0.01 ? v : nil
    }

    // MARK: right-now stat cards

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if let s = energy {
                stat("Price now", String(format: "€%.2f", s.priceEurPerKwh), "/kWh", "eurosign.circle.fill", Theme.amber)
                stat("Battery", "\(Int(s.battery.socPct.rounded()))%", batteryHint(s), "battery.100.bolt", Theme.green)
                stat("Solar now", String(format: "%.1f", s.solarKw), "kW", "sun.max.fill", Theme.green)
            }
            if let e = earnedToday {
                stat("Earning today", String(format: "€%.2f", e), "from solar", "arrow.up.right.circle.fill", Theme.green)
            }
        }
    }

    private func batteryHint(_ s: EnergyState) -> String {
        switch s.battery.state { case "charging": return "charging"; case "discharging": return "in use"; default: return "ready" }
    }

    private func stat(_ title: String, _ value: String, _ unit: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption).foregroundStyle(tint)
                Text(title).font(.caption).foregroundStyle(Theme.subtle)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                Text(unit).font(.caption2).foregroundStyle(Theme.subtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).cardSurface(14)
    }

    // MARK: Schaubild 1 — expected solar output

    private var solarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("Expected solar today", "sun.max.fill")
            if let peak = curve.max(by: { $0.solarKw < $1.solarKw }) {
                Text("Peaks at \(String(format: "%.1f", peak.solarKw)) kW around \(peak.hour):00.")
                    .font(.caption).foregroundStyle(Theme.subtle)
            }
            Chart(curve) { p in
                AreaMark(x: .value("Hour", p.hour), y: .value("kW", p.solarKw))
                    .foregroundStyle(LinearGradient(colors: [Theme.green.opacity(0.45), Theme.green.opacity(0.04)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Hour", p.hour), y: .value("kW", p.solarKw))
                    .foregroundStyle(Theme.green).interpolationMethod(.catmullRom)
            }
            .chartXScale(domain: 6...23)
            .chartXAxis { AxisMarks(values: [6, 12, 18, 23]) { v in
                AxisValueLabel { if let h = v.as(Int.self) { Text("\(h)").font(.system(size: 10)).foregroundStyle(Theme.subtle) } }
            } }
            .chartYAxis { AxisMarks(position: .leading) { AxisValueLabel().font(.system(size: 10)) } }
            .frame(height: 130)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface(16)
    }

    // MARK: anomaly + actions

    private func anomalyCard(_ a: InsightEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Needs a look", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.bold()).foregroundStyle(Theme.red)
            Text(a.title).font(.headline).foregroundStyle(Theme.ink)
            Text(a.detail).font(.subheadline).foregroundStyle(Theme.subtle)
                .fixedSize(horizontal: false, vertical: true)
            Button { dismiss(); onAsk() } label: {
                Text("Ask Lumen about it").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.red)
            }.buttonStyle(.plain)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.redSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.red.opacity(0.35), lineWidth: 1))
    }

    private var planButton: some View {
        Button { dismiss(); onPlan() } label: {
            Label("Plan my day", systemImage: "wand.and.stars")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
        }.buttonStyle(.plain)
    }

    private func cardTitle(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(Theme.green)
            Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
        }
    }
}
