import SwiftUI

@MainActor
final class DeviceSheetVM: ObservableObject {
    @Published var result: OptimizeResult?
    @Published var isLoading = false
    @Published var committing = false
    @Published var errorText: String?

    let device: Device
    let clock: DemoClock
    private let api = APIClient()

    init(device: Device, clock: DemoClock) { self.device = device; self.clock = clock }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do { result = try await api.optimize(device: device.id, clock: clock) }
        catch { errorText = error.localizedDescription }
    }
    func commit(start: String) async -> Bool {
        committing = true; defer { committing = false }
        do { _ = try await api.commit(device: device.id, start: start, clock: clock); return true }
        catch { errorText = error.localizedDescription; return false }
    }
}

struct DeviceSheetView: View {
    let device: Device
    let clock: DemoClock
    let onCommit: () async -> Void

    @StateObject private var vm: DeviceSheetVM
    @State private var selectedHour: Int = -1
    @Environment(\.dismiss) private var dismiss

    init(device: Device, clock: DemoClock, onCommit: @escaping () async -> Void) {
        self.device = device; self.clock = clock; self.onCommit = onCommit
        _vm = StateObject(wrappedValue: DeviceSheetVM(device: device, clock: clock))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let r = vm.result, let slot = selectedSlot(r) {
                    selectedTime(slot)
                    TimelinePicker(slots: r.slots, durationHours: r.durationHours,
                                   recommendedHour: hour(r.start), selectedHour: $selectedHour)
                    legend
                    metrics(slot)
                    if selectedHour != hour(r.start) { useGreenest(r) }
                    Text(phrase(slot)).font(.subheadline).foregroundStyle(Theme.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                    confirm(slot)
                } else if vm.isLoading {
                    ProgressView("Reading today’s energy…").frame(maxWidth: .infinity, minHeight: 280)
                } else if let e = vm.errorText {
                    Text(e).foregroundStyle(Theme.red).frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .warmScreen()
        .task { await vm.load() }
        .onChange(of: vm.result?.start) { _, newStart in
            if let s = newStart, selectedHour < 0 { selectedHour = hour(s) }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack { Circle().fill(tint.opacity(0.15)).frame(width: 46, height: 46)
                Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(tint) }
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.system(.title3).weight(.semibold)).foregroundStyle(Theme.ink)
                Text(String(format: "~%.1f kWh · %@", device.energyKwh, device.controllable ? "wallbox" : "appliance"))
                    .font(.caption).foregroundStyle(Theme.subtle)
            }
            Spacer()
        }
        .padding(.top, 6)
    }

    // The window the user has picked
    private func selectedTime(_ slot: OptimizeResult.DaySlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("when are you home?").font(.caption).foregroundStyle(Theme.subtle)
            Text(slot.window).font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.ink)
            HStack(spacing: 6) {
                Image(systemName: Source(slot.source) == .free ? "sun.max.fill" : Source(slot.source) == .partial ? "cloud.sun.fill" : "bolt.fill")
                Text(sourcePhrase(slot)).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Theme.source(slot.source))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.sourceSoft(slot.source), in: Capsule())
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach([Source.free, .partial, .paid], id: \.rawValue) { s in
                HStack(spacing: 5) {
                    Circle().fill(Theme.source(s.rawValue)).frame(width: 9, height: 9)
                    Text(Theme.sourceLabel(s.rawValue)).font(.caption).foregroundStyle(Theme.subtle)
                }
            }
            Spacer()
            Text("drag to pick").font(.caption2).foregroundStyle(Theme.subtle)
        }
    }

    private func metrics(_ slot: OptimizeResult.DaySlot) -> some View {
        HStack(spacing: 10) {
            metric("your share", "\(Int(slot.ownSharePct))%")
            metric("grid cost", String(format: "€%.2f", slot.gridCostEur))
        }
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(Theme.subtle)
            Text(value).font(.system(.title3).weight(.bold)).foregroundStyle(Theme.ink)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface(16)
    }

    private func useGreenest(_ r: OptimizeResult) -> some View {
        Button { withAnimation { selectedHour = hour(r.start) } } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("Use the greenest time · \(r.window) · free").font(.subheadline.weight(.medium))
                Spacer()
            }
            .foregroundStyle(Theme.green)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Theme.greenSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func confirm(_ slot: OptimizeResult.DaySlot) -> some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    if await vm.commit(start: slot.start) {
                        NotificationManager.scheduleReminder(deviceName: device.name, atHour: selectedHour)
                        await onCommit(); dismiss()
                    }
                }
            } label: {
                HStack {
                    if vm.committing { ProgressView().tint(.white) }
                    Image(systemName: "bell.fill")
                    Text(vm.committing ? "Scheduling…" : "Schedule & remind me").font(.system(.headline))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(vm.committing)
            Label(device.controllable
                  ? "We’ll start it for you and notify you at \(slot.window.prefix(5))."
                  : "We’ll remind you at \(slot.window.prefix(5)) to start it.",
                  systemImage: device.controllable ? "wand.and.stars" : "bell")
                .font(.caption2).foregroundStyle(Theme.subtle)
        }
    }

    // helpers
    private func selectedSlot(_ r: OptimizeResult) -> OptimizeResult.DaySlot? {
        r.slots.first { $0.hour == selectedHour && $0.feasible } ?? r.slots.first { $0.feasible }
    }
    private func hour(_ iso: String) -> Int { Int(iso.dropFirst(11).prefix(2)) ?? 13 }
    private var tint: Color {
        switch device.icon {
        case "car": return Theme.green
        case "bowl": return Theme.amber
        case "wash": return Theme.grid
        case "dryer": return Theme.grid
        case "shower": return Theme.amber
        case "flame": return Theme.red
        default: return Theme.green
        }
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
    private func sourcePhrase(_ slot: OptimizeResult.DaySlot) -> String {
        switch Source(slot.source) {
        case .free: return "Free — your own solar"
        case .partial: return "\(Int(slot.ownSharePct))% yours, rest grid"
        case .paid: return "From the grid"
        }
    }
    private func phrase(_ slot: OptimizeResult.DaySlot) -> String {
        switch Source(slot.source) {
        case .free: return "Free in this window — your solar and battery cover the \(device.name.lowercased())."
        case .partial: return "\(Int(slot.ownSharePct))% comes from your own energy here; the rest is about €\(String(format: "%.2f", slot.gridCostEur)) of grid power."
        case .paid: return "No solar to spare here — about €\(String(format: "%.2f", slot.gridCostEur)) from the grid. Drag to a greener slot to save it."
        }
    }
}

// MARK: - Interactive day timeline

private struct TimelinePicker: View {
    let slots: [OptimizeResult.DaySlot]
    let durationHours: Double
    let recommendedHour: Int
    @Binding var selectedHour: Int

    var body: some View {
        let dur = max(0.25, durationHours)
        let winHours = max(1, Int(ceil(dur)))
        let maxStart = max(0, 24 - winHours)
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let hourW = w / 24.0
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(slots) { s in
                            let inWin = s.hour >= selectedHour && s.hour < selectedHour + winHours
                            Rectangle().fill(Theme.source(s.source).opacity(s.feasible ? (inWin ? 1 : 0.4) : 0.15))
                        }
                    }
                    // recommended (greenest) marker
                    Rectangle().fill(Theme.ink.opacity(0.35)).frame(width: 2)
                        .offset(x: hourW * CGFloat(recommendedHour) + hourW * CGFloat(dur) / 2 - 1)
                    // selection window
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.ink, lineWidth: 3)
                        .frame(width: hourW * CGFloat(dur))
                        .offset(x: hourW * CGFloat(selectedHour))
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let h = Int((v.location.x / hourW).rounded(.down))
                    selectedHour = min(max(0, h), maxStart)
                })
            }
            .frame(height: 72)
            HStack { Text("00"); Spacer(); Text("06"); Spacer(); Text("12"); Spacer(); Text("18"); Spacer(); Text("24") }
                .font(.system(size: 10)).foregroundStyle(Theme.subtle)
        }
    }
}
