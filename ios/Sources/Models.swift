import Foundation

// MARK: - /now (the glance snapshot)
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

    struct Breakdown: Decodable, Sendable { let house: Double; let heatpump: Double; let ev: Double }
    struct Battery: Decodable, Sendable { let socPct: Double; let flowKw: Double; let state: String }
    struct Grid: Decodable, Sendable { let flowKw: Double; let direction: String }
}

// MARK: - /money
struct Money: Decodable, Sendable {
    let month: String
    let costToDateEur: Double
    let projectedTotalEur: Double
    let earnedFromSolarEur: Double
    let daysElapsed: Int
    let daysInMonth: Int
    let earning: Bool
}

// MARK: - /devices
struct Device: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let energyKwh: Double
    let powerKw: Double
    let controllable: Bool
    let status: String              // idle | scheduled
    let scheduled: Scheduled?
    struct Scheduled: Decodable, Sendable { let start: String; let window: String; let source: String }
}

// MARK: - /optimize_load
struct OptimizeResult: Decodable, Sendable {
    let device: String
    let deviceName: String
    let controllable: Bool
    let loadKwh: Double
    let start: String
    let end: String
    let window: String
    let source: String              // free | partial | paid
    let ownSharePct: Double
    let gridCostEur: Double
    let breakdownKwh: Breakdown
    let ribbon: [RibbonCell]
    let rationale: String
    struct Breakdown: Decodable, Sendable { let free: Double; let battery: Double; let grid: Double }
    struct RibbonCell: Decodable, Sendable, Identifiable {
        let hour: String; let source: String
        var id: String { hour }
    }
}

// MARK: - /insights
struct Insights: Decodable, Sendable {
    let health: String              // ok | alert
    let events: [InsightEvent]
}
struct InsightEvent: Decodable, Sendable, Identifiable {
    let type: String
    let severity: String
    let period: String
    let title: String
    let detail: String
    let suggestedAction: String
    let active: Bool
    var id: String { type + period + title }
}

struct CommitResponse: Decodable, Sendable {
    let committed: Bool
    let device: String
    let window: String
}

enum DemoClock: String, CaseIterable, Identifiable, Sendable {
    case summer, winter
    var id: String { rawValue }
    var label: String { self == .summer ? "Summer · now" : "Winter" }
}

/// free | partial | paid → semantic source used across tiles, ribbon, sheet.
enum Source: String {
    case free, partial, paid
    init(_ s: String) { self = Source(rawValue: s) ?? .paid }
}
