import Foundation
import SwiftUI

@MainActor final class PlanDayViewModel: ObservableObject {
    enum Phase { case pick, plan }

    struct TaskInput { var deadline: Date; var target: Int }   // target used by car only

    @Published var phase: Phase = .pick
    @Published var devices: [Device] = []
    @Published var selected: [String: TaskInput] = [:]         // deviceId → input
    @Published var mode: PlanMode = .cheapest
    @Published var plan: PlanResult?
    @Published var nudged: [String: String] = [:]              // deviceId → pinned start ISO
    @Published var isLoading = false
    @Published var errorText: String?

    let clockStore: ClockStore
    private let api = APIClient()
    init(clockStore: ClockStore) { self.clockStore = clockStore }
    var clock: DemoClock { clockStore.clock }

    func loadDevices() async {
        if let d = try? await api.devices(clock: clock) { devices = d }
    }

    func toggle(_ device: Device) {
        if selected[device.id] != nil { selected[device.id] = nil }
        else { selected[device.id] = TaskInput(deadline: defaultDeadline(for: device), target: 80) }
    }

    func makePlan() async { await runPlan(reset: true) }
    func replan() async { nudged.removeAll(); await runPlan(reset: true) }
    func setMode(_ m: PlanMode) { mode = m; Task { await runPlan(reset: false) } }

    /// Nudge a task ±1h, pin it, and re-plan the rest around it.
    func nudge(device: String, deltaHours: Int) {
        guard let t = plan?.tasks.first(where: { $0.device == device }) else { return }
        let base = nudged[device].flatMap(hour(fromISO:)) ?? t.startHour
        let h = min(23, max(0, base + deltaHours))
        nudged[device] = isoAtHour(h)
        Task { await runPlan(reset: false) }
    }

    private func runPlan(reset: Bool) async {
        isLoading = true; errorText = nil
        defer { isLoading = false }
        let inputs: [PlanTaskInput] = selected.map { (id, input) in
            PlanTaskInput(
                device: id,
                deadline: iso(from: input.deadline),
                target: id == "ev" ? input.target : nil,
                start: nudged[id]
            )
        }
        do {
            plan = try await api.planDay(tasks: inputs, mode: mode, clock: clock)
            phase = .plan
        } catch { errorText = error.localizedDescription }
    }

    // MARK: helpers

    private func defaultDeadline(for device: Device) -> Date {
        // base date = the demo "now" day; defaults: car 07:00 next day, appliances 20:00, boosts 19:00
        let cal = Calendar.current
        let now = nowDate()
        switch device.id {
        case "ev":
            let next = cal.date(byAdding: .day, value: 1, to: now) ?? now
            return cal.date(bySettingHour: 7, minute: 0, second: 0, of: next) ?? next
        case "hot_water", "heating_boost":
            return cal.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
        default:
            return cal.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        }
    }

    /// The demo clock's "now" as a Date (summer 2026-06-20T13:00, winter 2026-01-15T08:00).
    private func nowDate() -> Date {
        let iso = clock == .summer ? "2026-06-20T13:00:00" : "2026-01-15T08:00:00"
        return Self.formatter.date(from: iso) ?? Date()
    }
    private func iso(from d: Date) -> String { Self.formatter.string(from: d) }
    private func isoAtHour(_ h: Int) -> String {
        let cal = Calendar.current
        let base = cal.date(bySettingHour: h, minute: 0, second: 0, of: nowDate()) ?? nowDate()
        return Self.formatter.string(from: base)
    }
    private func hour(fromISO iso: String) -> Int? { Int(iso.dropFirst(11).prefix(2)) }

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        return f
    }()
}
