import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var clock: DemoClock = .summer
    @Published var state: EnergyState?
    @Published var money: Money?
    @Published var devices: [Device] = []
    @Published var insights: Insights?
    @Published var isLoading = false
    @Published var errorText: String?

    let api = APIClient()

    func loadAll() async {
        isLoading = true; errorText = nil
        defer { isLoading = false }
        do {
            async let s = api.state(clock: clock)
            async let m = api.money(clock: clock)
            async let d = api.devices(clock: clock)
            async let i = api.insights(clock: clock)
            state = try await s; money = try await m; devices = try await d; insights = try await i
        } catch {
            errorText = error.localizedDescription
        }
    }

    func reloadDevices() async {
        if let d = try? await api.devices(clock: clock) { devices = d }
    }

    func setClock(_ c: DemoClock) {
        guard c != clock else { return }
        clock = c
        Task { try? await api.reset(); await loadAll() }  // fresh ledger per clock for clean demos
    }

    var activeAnomaly: InsightEvent? {
        insights?.events.first { $0.active && $0.type == "anomaly" && $0.severity == "high" }
    }
    var proactiveCards: [InsightEvent] {
        insights?.events.filter { $0.active && $0.type != "anomaly" } ?? []
    }

    var verdict: String {
        guard let s = state else { return "" }
        switch s.status {
        case "exporting_surplus":
            return "You're running on free solar right now — and sending \(fmt(s.grid.flowKw)) kW back to the grid."
        case "drawing_grid":
            return "You're drawing \(fmt(-s.grid.flowKw)) kW from the grid — the sun isn't covering the house right now."
        default:
            return "You're running entirely on your own power right now."
        }
    }

    var moneyLine: String {
        guard let m = money else { return "" }
        let v = Int(m.projectedTotalEur.rounded())
        return m.earning ? "On track to earn €\(abs(v)) this month" : "On track for €\(v) this month"
    }

    func fmt(_ v: Double) -> String { String(format: "%.1f", abs(v)) }
}
