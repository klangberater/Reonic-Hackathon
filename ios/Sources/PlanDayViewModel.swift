import Foundation
import SwiftUI

@MainActor final class PlanDayViewModel: ObservableObject {
    enum Phase { case pick, plan }
    enum VoicePhase: Equatable { case idle, transcribing, planning }   // post-recording stages

    struct TaskInput { var deadline: Date; var target: Int }   // target used by car only

    @Published var phase: Phase = .pick
    @Published var devices: [Device] = []
    @Published var selected: [String: TaskInput] = [:]         // deviceId → input
    @Published var mode: PlanMode = .cheapest
    @Published var plan: PlanResult?
    @Published var nudged: [String: String] = [:]              // deviceId → pinned start ISO
    @Published var insights: Insights?                         // powers the header status chip
    @Published var state: EnergyState?                         // powers the verdict line (same as Home)
    @Published var money: Money?                                // month-end forecast, shown in the flow sheet
    @Published var isLoading = false
    @Published var errorText: String?

    // Conversational voice/text plan
    @Published var voicePhase: VoicePhase = .idle
    @Published var transcript = ""
    @Published var voiceError: String?
    @Published var didReveal = false                           // true → planState shows the big money reveal
    @Published var planNotes: [String] = []                    // acknowledged context (e.g. "Guests at 8pm")
    @Published var remindersSet = false                        // "Remind me" tapped → notifications scheduled
    @Published var remindersDenied = false                     // notification permission was refused
    private let player = AudioPlayer.shared

    let clockStore: ClockStore
    private let api = APIClient()
    init(clockStore: ClockStore) { self.clockStore = clockStore }
    var clock: DemoClock { clockStore.clock }

    /// Same predicate as Home so the status chip reads identically across screens.
    var activeAnomaly: InsightEvent? {
        insights?.events.first { $0.active && $0.type == "anomaly" && $0.severity == "high" }
    }

    /// Tasks offered on the Plan screen — the hot-water and heating boosts are excluded.
    private static let hiddenDeviceIDs: Set<String> = ["hot_water", "heating_boost"]
    var planDevices: [Device] { devices.filter { !Self.hiddenDeviceIDs.contains($0.id) } }

    /// Same wording as Home's verdict line.
    var verdict: String {
        guard let s = state else { return "" }
        switch s.status {
        case "exporting_surplus": return "Running on free solar — sending \(fmt(s.grid.flowKw)) kW to the grid."
        case "drawing_grid": return "Pulling \(fmt(-s.grid.flowKw)) kW from the grid right now."
        default: return "Running on your own power right now."
        }
    }
    private func fmt(_ v: Double) -> String { String(format: "%.1f", abs(v)) }

    func loadDevices() async {
        async let d = try? await api.devices(clock: clock)
        async let i = try? await api.insights(clock: clock)
        async let s = try? await api.state(clock: clock)
        async let mo = try? await api.money(clock: clock)
        if let d = await d { devices = d }
        insights = await i
        state = await s
        money = await mo
    }

    func toggle(_ device: Device) {
        if selected[device.id] != nil { selected[device.id] = nil }
        else { selected[device.id] = TaskInput(deadline: defaultDeadline(for: device), target: 80) }
    }

    func makePlan() async { await runPlan() }
    func replan() async { nudged.removeAll(); await runPlan() }
    func setMode(_ m: PlanMode) { mode = m; Task { await runPlan() } }

    /// One-tap "preview my day": plan every heavy appliance the home has at its default deadline,
    /// so the agenda shows the best times to charge / run them — no manual picking needed.
    func recommendDay() async {
        if devices.isEmpty { await loadDevices() }
        nudged.removeAll(); transcript = ""; voiceError = nil
        selected = Dictionary(uniqueKeysWithValues:
            planDevices.map { ($0.id, TaskInput(deadline: defaultDeadline(for: $0), target: 80)) })
        await runPlan(reveal: true)
    }

    // MARK: reminders — notify the user when each task should run

    /// Schedule a local notification for each planned task at its start time.
    func scheduleReminders() {
        guard let tasks = plan?.tasks else { return }
        let reminders = tasks.map { t in
            NotificationManager.Reminder(
                id: t.device,
                title: "Time to \(reminderVerb(t.device))",
                body: reminderBody(t),
                fireAt: reminderFireDate(t))
        }
        NotificationManager.schedulePlan(reminders) { [weak self] granted in
            self?.remindersSet = granted
            self?.remindersDenied = !granted
        }
    }

    private func reminderVerb(_ device: String) -> String {
        switch device {
        case "ev": return "charge the car"
        case "dishwasher": return "run the dishwasher"
        case "washing_machine": return "run the washing machine"
        case "dryer": return "run the dryer"
        default: return "run it"
        }
    }

    private func reminderBody(_ t: PlanResult.PlannedTask) -> String {
        let end = String(t.window.suffix(5))
        switch t.source {
        case "free":
            switch t.ownSource {
            case "battery": return "Free — runs on your stored battery until \(end)."
            case "mixed":   return "Free — your solar + battery cover it until \(end)."
            default:        return "Free solar window — runs on sunshine until \(end)."
            }
        case "partial": return "Your greenest window — part solar, part grid, until \(end)."
        default:        return "The cheapest window available, until \(end)."
        }
    }

    /// The real wall-clock moment to fire: today (or +N days, matching the plan's day) at the
    /// task's time-of-day, so reminders land at sensible times even with a pinned demo clock.
    private func reminderFireDate(_ t: PlanResult.PlannedTask) -> Date {
        let cal = berlinCal
        guard let taskStart = Self.formatter.date(from: String(t.start.prefix(19))) else {
            return Date().addingTimeInterval(8)
        }
        let dayOffset = cal.dateComponents([.day],
            from: cal.startOfDay(for: nowDate()),
            to: cal.startOfDay(for: taskStart)).day ?? 0
        let hm = cal.dateComponents([.hour, .minute], from: taskStart)
        let base = cal.date(byAdding: .day, value: max(0, dayOffset), to: cal.startOfDay(for: Date())) ?? Date()
        return cal.date(bySettingHour: hm.hour ?? 9, minute: hm.minute ?? 0, second: 0, of: base) ?? base
    }

    // MARK: conversational plan (voice → STT → parse → plan → spoken verdict)

    /// Spoken clip → transcript → plan. Drives the three on-stage status beats.
    func planFromVoice(audio: Data, mime: String) async {
        voiceError = nil
        voicePhase = .transcribing
        do {
            transcript = try await api.transcribe(audio: audio, mime: mime)
            await runVoicePlan(text: transcript)
        } catch {
            voicePhase = .idle
            voiceError = error.localizedDescription
        }
    }

    /// Demo-safe fallback: type the sentence, skip the mic.
    func planFromText(_ typed: String) async {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        transcript = text
        voiceError = nil
        await runVoicePlan(text: text)
    }

    private func runVoicePlan(text: String) async {
        guard !text.isEmpty else { voicePhase = .idle; voiceError = "I didn't catch that — try again, or type it below."; return }
        if devices.isEmpty { await loadDevices() }   // need the library to mirror parsed tasks into `selected`
        voicePhase = .planning
        do {
            let result = try await api.planText(text: text, mode: mode, clock: clock)
            applyParsed(result.tasks)                // keep re-plan / mode-toggle / nudge working
            planNotes = result.notes ?? []
            plan = result.plan
            phase = .plan
            didReveal = true
            voicePhase = .idle
            if let data = Data(base64Encoded: result.speechBase64) { player.play(data) }
        } catch {
            voicePhase = .idle
            voiceError = error.localizedDescription
        }
    }

    /// Mirror the backend-parsed tasks into `selected` so the existing manual controls keep operating.
    private func applyParsed(_ tasks: [PlanTextResult.ParsedTask]) {
        selected.removeAll()
        nudged.removeAll()
        for t in tasks {
            guard let device = devices.first(where: { $0.id == t.device }) else { continue }
            let deadline = t.deadline.flatMap { Self.formatter.date(from: String($0.prefix(19))) }
                ?? defaultDeadline(for: device)
            selected[t.device] = TaskInput(deadline: deadline, target: t.target ?? 80)
        }
    }

    /// Nudge a task ±1h, pin it, and re-plan the rest around it.
    func nudge(device: String, deltaHours: Int) {
        guard let t = plan?.tasks.first(where: { $0.device == device }) else { return }
        let base = nudged[device].flatMap(hour(fromISO:)) ?? t.startHour
        let h = min(23, max(6, base + deltaHours))   // keep within the 06–23 timeline axis
        nudged[device] = isoAtHour(h)
        Task { await runPlan() }
    }

    private func runPlan(reveal: Bool = false) async {
        isLoading = true; errorText = nil
        planNotes = []
        remindersSet = false; remindersDenied = false   // a changed plan needs fresh reminders
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
            didReveal = reveal   // recommend/voice show the day-summary reveal; manual keeps the compact chip
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

    /// The clock's "now": summer tracks the real wall clock (pinned to the data year so it
    /// exists in the dataset, matching the backend); winter stays fixed for the anomaly demo.
    private func nowDate() -> Date {
        if clock == .winter { return Self.formatter.date(from: "2026-01-15T08:00:00") ?? Date() }
        if clock == .summerday { return Self.formatter.date(from: "2026-06-20T11:00:00") ?? Date() }
        let cal = berlinCal
        var c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        c.year = 2026
        c.minute = ((c.minute ?? 0) / 15) * 15
        c.second = 0
        return cal.date(from: c) ?? Date()
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
        // Anchor everything to the virtual "now" (`vnow`), not the real wall clock, so the
        // pinned demo clocks (Sunny / Winter) roll deadlines coherently rather than against
        // whatever time it happens to be on stage.
        let cal = berlinCal
        let vnow = nowDate()
        let hm = cal.dateComponents([.hour, .minute], from: chosen)
        var deadline = cal.date(bySettingHour: hm.hour ?? 20, minute: hm.minute ?? 0, second: 0, of: vnow) ?? vnow
        while deadline <= vnow { deadline = cal.date(byAdding: .day, value: 1, to: deadline) ?? deadline }
        return deadline
    }

    /// "Today" / "Tomorrow" / "+Nd" for a planned task's start ISO, relative to the demo day.
    func dayLabel(forISO iso: String) -> String {
        let cal = berlinCal
        guard let d = Self.formatter.date(from: String(iso.prefix(19))) else { return "" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: nowDate()), to: cal.startOfDay(for: d)).day ?? 0
        return days <= 0 ? "Today" : days == 1 ? "Tomorrow" : "+\(days)d"
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
