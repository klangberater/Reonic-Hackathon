import Foundation

/// Mirrors GET /state (tool #1 get_current_state). Decoded with .convertFromSnakeCase.
struct EnergyState: Decodable, Sendable {
    let householdId: String
    let householdName: String
    let at: String
    let outdoorTempC: Double
    let solarKw: Double
    let consumptionKw: Double
    let breakdownKw: Breakdown
    let battery: Battery
    let grid: Grid
    let priceEurPerKwh: Double
    let netKw: Double
    let status: String

    struct Breakdown: Decodable, Sendable {
        let house: Double
        let heatpump: Double
        let ev: Double
    }
    struct Battery: Decodable, Sendable {
        let socPct: Double
        let flowKw: Double
        let state: String   // charging | discharging | idle
    }
    struct Grid: Decodable, Sendable {
        let flowKw: Double
        let direction: String  // exporting | importing | balanced
    }
}

enum DemoClock: String, CaseIterable, Identifiable, Sendable {
    case summer, winter
    var id: String { rawValue }
    var label: String { self == .summer ? "Summer · now" : "Winter" }
}
