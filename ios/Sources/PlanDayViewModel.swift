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

    func makePlan() async { await runPlan() }
    func replan() async { nudged.removeAll(); await runPlan() }
    func setMode(_ m: PlanMode) { mode = m; Task { await runPlan() } }

    /// Nudge a task ±1h, pin it, and re-plan the rest around it.
    func nudge(device: String, deltaHours: Int) {
        guard let t = plan?.tasks.first(where: { $0.device == device }) else { return }
        let base = nudged[device].flatMap(hour(fromISO:)) ?? t.startHour
        let h = min(23, max(6, base + deltaHours))   // keep within the 06–23 timeline axis
        nudged[device] = isoAtHour(h)
        Task { await runPlan() }
    }

    private func runPlan() async {
        isLoading = true; errorText = nil
        defer { isLoading = false }
        let inputs: [PlanTaskInput] = selected.map { (id, input) in
            PlanTaskInput(
                device: id,
                deadline: iso(from: normalizedDeadline(input.deadline)),
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

    private var berlinCal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return c
    }

    /// Resolve a picked time-of-day into a concrete deadline. The picker only gives a time, so
    /// we anchor it to the demo day and roll it to the next day when that time has already passed
    /// on the real clock (pick 11am at 18:27 → tomorrow 11am). The planner reasons from the demo
    /// "now", so the result is always strictly after it.
    func normalizedDeadline(_ chosen: Date) -> Date {
        let cal = berlinCal
        let vnow = nowDate()
        let hm = cal.dateComponents([.hour, .minute], from: chosen)
        var deadline = cal.date(bySettingHour: hm.hour ?? 20, minute: hm.minute ?? 0, second: 0, of: vnow) ?? vnow
        let nowHM = cal.dateComponents([.hour, .minute], from: Date())
        let chosenMin = (hm.hour ?? 0) * 60 + (hm.minute ?? 0)
        let realMin = (nowHM.hour ?? 0) * 60 + (nowHM.minute ?? 0)
        if chosenMin <= realMin { deadline = cal.date(byAdding: .day, value: 1, to: deadline) ?? deadline }
        while deadline <= vnow { deadline = cal.date(byAdding: .day, value: 1, to: deadline) ?? deadline }
        return deadline
    }

    /// "today" / "tomorrow" / "+2d" label for a picked deadline, relative to the demo day.
    func dayHint(for chosen: Date) -> String {
        let cal = berlinCal
        let days = cal.dateComponents([.day],
            from: cal.startOfDay(for: nowDate()),
            to: cal.startOfDay(for: normalizedDeadline(chosen))).day ?? 0
        return days <= 0 ? "today" : days == 1 ? "tomorrow" : "+\(days)d"
    }
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
