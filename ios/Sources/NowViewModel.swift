import Foundation
import SwiftUI

@MainActor
final class NowViewModel: ObservableObject {
    @Published var state: EnergyState?
    @Published var clock: DemoClock = .summer
    @Published var isLoading = false
    @Published var errorText: String?

    private let api = APIClient()

    func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            state = try await api.state(clock: clock)
        } catch {
            errorText = error.localizedDescription
        }
    }

    func setClock(_ c: DemoClock) {
        guard c != clock else { return }
        clock = c
        Task { await load() }
    }

    /// Plain-language verdict for the glance. Placeholder for an LLM-generated line
    /// once /chat lands — keeps the "tools do the math, the model does the words" split.
    var verdict: String {
        guard let s = state else { return "" }
        let name = s.householdName.components(separatedBy: " ").last ?? "your home"
        switch s.status {
        case "exporting_surplus":
            return "Right now you're making more than you use — your battery is \(Int(s.battery.socPct))% and you're sending \(fmt(s.grid.flowKw)) kW to the grid."
        case "drawing_grid":
            let imp = -s.grid.flowKw
            return "You're pulling \(fmt(imp)) kW from the grid — the sun isn't covering \(name)'s load right now."
        default:
            return "You're running entirely on your own power right now — nothing flowing to or from the grid."
        }
    }

    func fmt(_ v: Double) -> String { String(format: "%.1f", abs(v)) }
}
