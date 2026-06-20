import SwiftUI

struct PlanDayView: View {
    @StateObject private var vm: PlanDayViewModel
    @ObservedObject private var clockStore: ClockStore
    @StateObject private var voice = VoiceRecorder()
    @State private var selectedBlock: String?
    @State private var showSettings = false
    @State private var showFlow = false
    @State private var typed = ""
    @FocusState private var typingFocused: Bool

    init(clock: ClockStore) {
        _vm = StateObject(wrappedValue: PlanDayViewModel(clockStore: clock))
        _clockStore = ObservedObject(wrappedValue: clock)
    }

    var body: some View {
        Group {
            switch vm.phase {
            case .pick: pickState
            case .plan: planState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .warmScreen()
        .task { if vm.devices.isEmpty { await vm.loadDevices() } }
        .onChange(of: clockStore.clock) { _, _ in Task { await vm.loadDevices() } }
        .sheet(isPresented: $showSettings) { SettingsView(clock: clockStore).presentationDetents([.medium]) }
        .sheet(isPresented: $showFlow) { if let s = vm.state { FlowDetailView(state: s) } }
    }

    // Verdict: small, informative line (tap for the live flow) — same as Home.
    @ViewBuilder private var verdictLine: some View {
        if vm.state != nil {
            Button { showFlow = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: heroIcon).font(.footnote).foregroundStyle(Theme.green)
                    Text(vm.verdict).font(.subheadline).foregroundStyle(Theme.subtle)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.subtle)
                }
            }.buttonStyle(.plain)
        }
    }

    private var heroIcon: String {
        switch vm.state?.status {
        case "exporting_surplus": return "sun.max.fill"
        case "drawing_grid": return "bolt.fill"
        default: return "leaf.fill"
        }
    }

    // Settings + a quick health overview, mirroring Home's header. Sits atop each state.
    private var topBar: some View {
        HStack(spacing: 12) {
            statusChip
            Spacer()
            PagerDots(current: 1)
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").font(.title3).foregroundStyle(Theme.subtle)
            }
            .accessibilityLabel("Settings")
        }
    }

    private var statusChip: some View {
        let alert = vm.activeAnomaly != nil
        return HStack(spacing: 6) {
            Circle().fill(alert ? Theme.red : Theme.green).frame(width: 8, height: 8)
            Text(alert ? "Attention" : "All good").font(.caption.weight(.medium)).foregroundStyle(alert ? Theme.red : Theme.green)
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(alert ? Theme.redSoft : Theme.greenSoft, in: Capsule())
    }

    // MARK: Voice — the conversational entry (top of the Plan screen)

    private var voiceBar: some View {
        VStack(spacing: 14) {
            Button { Task { await toggleRecording() } } label: {
                ZStack {
                    Circle().fill(Theme.greenSoft)
                        .frame(width: 96, height: 96)
                        .scaleEffect(1 + (voice.isRecording ? voice.level * 0.4 : 0))
                        .animation(.easeOut(duration: 0.08), value: voice.level)
                    Circle().fill(voice.isRecording ? Theme.red : Theme.green).frame(width: 72, height: 72)
                    if vm.voicePhase != .idle {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: voice.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(vm.voicePhase != .idle)

            Text(voicePrompt).font(.subheadline.weight(.medium)).foregroundStyle(Theme.subtle)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)

            if !vm.transcript.isEmpty {
                Text("\u{201C}\(vm.transcript)\u{201D}")
                    .font(.callout.weight(.medium)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                TextField("or type it here\u{2026}", text: $typed)
                    .textFieldStyle(.plain).font(.subheadline).foregroundStyle(Theme.ink)
                    .focused($typingFocused).submitLabel(.go)
                    .onSubmit { submitTyped() }
                Button { submitTyped() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                        .foregroundStyle(typed.isEmpty ? Theme.subtle.opacity(0.5) : Theme.green)
                }
                .disabled(typed.isEmpty || vm.voicePhase != .idle)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Theme.bg, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))

            if let e = vm.voiceError { Text(e).font(.footnote).foregroundStyle(Theme.red).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity)
        .padding(20).cardSurface(22)
    }

    private var voicePrompt: String {
        if voice.isRecording { return "Listening\u{2026} tap to finish" }
        switch vm.voicePhase {
        case .transcribing: return "Understanding what you said\u{2026}"
        case .planning: return "Laying it under the sun\u{2026}"
        case .idle: return vm.transcript.isEmpty
            ? "Tap and tell me your day — \u{201C}charge the car by morning, and a load of washing\u{201D}"
            : "Tap to plan something else"
        }
    }

    private func submitTyped() {
        let text = typed
        typed = ""
        typingFocused = false
        Task { await vm.planFromText(text) }
    }

    private func toggleRecording() async {
        if voice.isRecording {
            let data = voice.stop()
            if let data { await vm.planFromVoice(audio: data, mime: voice.mime) }
            else { vm.voiceError = "I didn't catch any audio — try again, or type it below." }
            return
        }
        guard await voice.requestPermission() else {
            vm.voiceError = "Microphone access is off — enable it in Settings, or type below."
            return
        }
        vm.voiceError = nil
        vm.transcript = ""
        do { try voice.start() } catch { vm.voiceError = error.localizedDescription }
    }

    // MARK: State 1 — pick

    private var pickState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                verdictLine
                voiceBar
                HStack(spacing: 10) {
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                    Text("or pick manually").font(.caption).foregroundStyle(Theme.subtle).fixedSize()
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(vm.planDevices) { d in
                        TaskCard(device: d, selected: vm.selected[d.id] != nil) { vm.toggle(d) }
                    }
                }
                ForEach(vm.planDevices.filter { vm.selected[$0.id] != nil }) { d in
                    taskRow(d)
                }
                if let e = vm.errorText { Text(e).font(.footnote).foregroundStyle(Theme.red) }
                makeButton
                anomalyCard
            }
            .padding(20)
        }
    }

    // Surfaced below "Make my plan" when the home has a live anomaly (e.g. the heat-pump fault).
    @ViewBuilder private var anomalyCard: some View {
        if let a = vm.activeAnomaly {
            VStack(alignment: .leading, spacing: 8) {
                Label("Needs a look", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold()).foregroundStyle(Theme.red)
                Text(a.title).font(.system(.headline)).foregroundStyle(Theme.ink)
                Text(a.detail).font(.subheadline).foregroundStyle(Theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                Text(a.suggestedAction).font(.footnote.weight(.medium)).foregroundStyle(Theme.red)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.redSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.red.opacity(0.35), lineWidth: 1))
        }
    }

    private func taskRow(_ d: Device) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol(d.icon)).foregroundStyle(Theme.green)
                Text(d.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                if let input = vm.selected[d.id] {
                    Text("ready by \(vm.dayHint(for: input.deadline))").font(.caption).foregroundStyle(Theme.subtle)
                }
                DatePicker("", selection: Binding(
                    get: { vm.selected[d.id]?.deadline ?? Date() },
                    set: { vm.selected[d.id]?.deadline = $0 }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
            }
            if d.id == "ev", let input = vm.selected[d.id] {
                HStack {
                    Text("Charge to \(input.target)%").font(.caption).foregroundStyle(Theme.subtle)
                    Slider(value: Binding(
                        get: { Double(vm.selected[d.id]?.target ?? 80) },
                        set: { vm.selected[d.id]?.target = Int($0) }
                    ), in: 50...100, step: 5)
                    .tint(Theme.green)
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface(16)
    }

    private var makeButton: some View {
        Button { Task { await vm.makePlan() } } label: {
            HStack {
                if vm.isLoading { ProgressView().tint(.white) }
                Image(systemName: "wand.and.stars")
                Text(vm.isLoading ? "Planning\u{2026}"
                     : vm.selected.isEmpty ? "Make my plan"
                     : "Make my plan \u{00B7} \(vm.selected.count)").font(.headline)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(vm.selected.isEmpty ? Theme.hairline : Theme.green,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
        }
        .disabled(vm.selected.isEmpty || vm.isLoading)
    }

    // MARK: State 2 — plan

    @ViewBuilder private var planState: some View {
        if let p = vm.plan {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Button { vm.phase = .pick } label: {
                            Label("Edit tasks", systemImage: "chevron.left").font(.subheadline)
                        }.buttonStyle(.plain).foregroundStyle(Theme.subtle)
                        Spacer()
                        statusChip
                        PagerDots(current: 1)
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape").font(.title3).foregroundStyle(Theme.subtle)
                        }
                        .accessibilityLabel("Settings")
                    }
                    if vm.didReveal {
                        MoneyReveal(plan: p).id(p.tasks.map(\.window).joined())
                        if !vm.planNotes.isEmpty { noteChips }
                    } else {
                        summaryChip(p)
                    }
                    Picker("Mode", selection: Binding(get: { vm.mode }, set: { vm.setMode($0) })) {
                        ForEach(PlanMode.allCases) { m in Text(m.label).tag(m) }
                    }
                    .pickerStyle(.segmented)

                    DayTimeline(curve: p.curve, tasks: p.tasks, selected: selectedBlock) { dev in
                        selectedBlock = (selectedBlock == dev) ? nil : dev
                    }

                    if let dev = selectedBlock, let t = p.tasks.first(where: { $0.device == dev }) {
                        nudgeBar(t)
                    }

                    orderedList(p)

                    Button { Task { selectedBlock = nil; await vm.replan() } } label: {
                        Label("Re-plan", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.greenSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(Theme.green)
                    }.buttonStyle(.plain)
                }
                .padding(20)
            }
        } else {
            ProgressView("Planning\u{2026}").frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    // Acknowledged context the planner heard but didn't schedule (e.g. "Guests at 8pm").
    private var noteChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(vm.planNotes, id: \.self) { note in
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill").font(.caption).foregroundStyle(Theme.subtle)
                    Text("Noted: \(note)").font(.subheadline).foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            }
        }
    }

    private func summaryChip(_ p: PlanResult) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf.fill")
            Text("\(Int(p.solarSharePct))% solar \u{00B7} saves \u{20AC}\(String(format: "%.2f", p.savedEur)) / \(String(format: "%.0f", p.savedCo2Kg)) kg CO\u{2082} today")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Theme.green)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.greenSoft, in: Capsule())
    }

    private func nudgeBar(_ t: PlanResult.PlannedTask) -> some View {
        HStack {
            Text("\(t.displayName) \u{00B7} \(t.window)").font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
            Spacer()
            Button { vm.nudge(device: t.device, deltaHours: -1) } label: { Image(systemName: "minus.circle.fill") }
            Text("nudge").font(.caption).foregroundStyle(Theme.subtle)
            Button { vm.nudge(device: t.device, deltaHours: 1) } label: { Image(systemName: "plus.circle.fill") }
        }
        .font(.title3).foregroundStyle(Theme.green)
        .padding(14).cardSurface(14)
    }

    private func orderedList(_ p: PlanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(p.tasks.sorted { $0.startHour < $1.startHour }) { t in
                HStack(spacing: 10) {
                    Text(String(t.window.prefix(5))).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                        .frame(width: 52, alignment: .leading)
                    Image(systemName: symbol(t.icon)).foregroundStyle(Theme.source(t.source))
                    Text(t.displayName).font(.subheadline).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(Theme.sourceLabel(t.source)).font(.caption).foregroundStyle(Theme.source(t.source))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface(16)
    }

    private func symbol(_ icon: String) -> String {
        switch icon {
        case "car": return "car.fill"
        case "bowl": return "dishwasher.fill"
        case "wash": return "washer.fill"
        case "dryer": return "dryer.fill"
        case "shower": return "shower.fill"
        case "flame": return "flame.fill"
        default: return "powerplug.fill"
        }
    }
}

/// A multi-select task card for State 1.
private struct TaskCard: View {
    let device: Device
    let selected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 26)).foregroundStyle(Theme.green)
                Text(device.displayName).font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(selected ? Theme.greenSoft : Theme.card,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? Theme.green : Theme.hairline, lineWidth: 1))
            .overlay(alignment: .topTrailing) { selectionMark }
        }.buttonStyle(.plain)
    }

    // Always-visible selection affordance: filled green check when picked, empty circle otherwise.
    @ViewBuilder private var selectionMark: some View {
        Group {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Theme.green)
            } else {
                Image(systemName: "circle").foregroundStyle(Theme.subtle.opacity(0.6))
            }
        }
        .font(.title3).padding(10)
    }
    private var symbol: String {
        switch device.icon {
        case "car": return "car.fill"
        case "bowl": return "dishwasher.fill"
        case "wash": return "washer.fill"
        case "dryer": return "dryer.fill"
        case "shower": return "shower.fill"
        case "flame": return "flame.fill"
        default: return "powerplug.fill"
        }
    }
}

/// The savings gut-punch after a conversational plan: the optimised cost rolls up against the
/// struck-through baseline, with a spring entrance. Numbers come straight from the plan.
private struct MoneyReveal: View {
    let plan: PlanResult
    @State private var shown = false
    @State private var amount: Double

    init(plan: PlanResult) {
        self.plan = plan
        let baseline = plan.tasks.reduce(0) { $0 + $1.gridCostEur } + plan.savedEur
        _amount = State(initialValue: baseline)
    }

    private var optimized: Double { plan.tasks.reduce(0) { $0 + $1.gridCostEur } }
    private var baseline: Double { optimized + plan.savedEur }
    private var savings: Bool { plan.savedEur >= 0.05 }

    var body: some View {
        VStack(spacing: 8) {
            Text(plan.solarSharePct >= 80 && savings ? "All done on sunshine" : "Here's your day, planned")
                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.green)
            Text(euro(amount))
                .font(.system(size: 54, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: amount))
                .monospacedDigit()
            if savings {
                Text("instead of \(euro(baseline))")
                    .font(.headline).foregroundStyle(Theme.subtle).strikethrough()
            }
            Text("\(Int(plan.solarSharePct))% on your own power \u{00B7} \(String(format: "%.0f", plan.savedCo2Kg)) kg CO\u{2082} saved")
                .font(.footnote).foregroundStyle(Theme.subtle)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 22).padding(.horizontal, 16)
        .background(Theme.greenSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.green.opacity(0.3), lineWidth: 1))
        .scaleEffect(shown ? 1 : 0.85).opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { shown = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) { amount = optimized }
        }
    }

    private func euro(_ v: Double) -> String { "\u{20AC}" + String(format: "%.2f", v) }
}
