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
    let durationHours: Double
    let breakdownKwh: Breakdown
    let slots: [DaySlot]
    let rationale: String
    struct Breakdown: Decodable, Sendable { let free: Double; let battery: Double; let grid: Double }
    struct DaySlot: Decodable, Sendable, Identifiable {
        let hour: Int; let start: String; let window: String; let source: String
        let ownSharePct: Double; let gridCostEur: Double; let feasible: Bool
        var id: Int { hour }
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

// MARK: - /chat
struct ChatMessage: Identifiable, Sendable {
    let id = UUID()
    let role: String      // user | assistant
    var content: String
}
struct ChatResponse: Decodable, Sendable {
    let reply: String
    let toolsUsed: [String]
}

/// free | partial | paid → semantic source used across tiles, ribbon, sheet.
enum Source: String {
    case free, partial, paid
    init(_ s: String) { self = Source(rawValue: s) ?? .paid }
}

// MARK: - /plan_day
struct PlanResult: Decodable, Sendable {
    let mode: String
    let solarSharePct: Double
    let savedEur: Double
    let savedCo2Kg: Double
    let curve: [CurvePoint]
    let tasks: [PlannedTask]

    struct CurvePoint: Decodable, Sendable, Identifiable {
        let hour: Int; let solarKw: Double
        var id: Int { hour }
    }
    struct PlannedTask: Decodable, Sendable, Identifiable {
        let device: String; let name: String; let icon: String
        let start: String; let startHour: Int; let window: String
        let durationHours: Double; let source: String
        let ownSharePct: Double; let gridCostEur: Double; let controllable: Bool
        var id: String { device }
    }
}

enum PlanMode: String, CaseIterable, Identifiable, Sendable {
    case cheapest, greenest, soonest
    var id: String { rawValue }
    var label: String { self == .cheapest ? "Cheapest" : self == .greenest ? "Greenest" : "Soonest" }
}

/// User-facing label for a task — an action verb on the actionable appliances; the heat
/// boosts keep their backend name. The backend `name` stays semantic (used in the planner's
/// generated sentences), so the verbs live UI-side only.
func taskDisplayName(id: String, fallback: String) -> String {
    switch id {
    case "ev": return "Charge Car"
    case "dishwasher": return "Run Dishwasher"
    case "washing_machine": return "Run Washing Machine"
    case "dryer": return "Run Dryer"
    default: return fallback
    }
}
extension Device { var displayName: String { taskDisplayName(id: id, fallback: name) } }
extension PlanResult.PlannedTask { var displayName: String { taskDisplayName(id: device, fallback: name) } }
