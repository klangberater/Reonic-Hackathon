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
    func commit() async -> Bool {
        committing = true; defer { committing = false }
        do { _ = try await api.commit(device: device.id, clock: clock); return true }
        catch { errorText = error.localizedDescription; return false }
    }
}

struct DeviceSheetView: View {
    let device: Device
    let clock: DemoClock
    let onCommit: () async -> Void

    @StateObject private var vm: DeviceSheetVM
    @Environment(\.dismiss) private var dismiss

    init(device: Device, clock: DemoClock, onCommit: @escaping () async -> Void) {
        self.device = device; self.clock = clock; self.onCommit = onCommit
        _vm = StateObject(wrappedValue: DeviceSheetVM(device: device, clock: clock))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if let r = vm.result {
                bestTime(r)
                ribbon(r)
                metrics(r)
                Text(r.rationale).font(.subheadline).foregroundStyle(Theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                confirm(r)
            } else if vm.isLoading {
                ProgressView("Finding the greenest time…").frame(maxWidth: .infinity, minHeight: 260)
            } else if let e = vm.errorText {
                Text(e).foregroundStyle(Theme.red).frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .warmScreen()
        .task { await vm.load() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(Theme.subtle)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.system(.title3, design: .rounded).weight(.semibold)).foregroundStyle(Theme.ink)
                Text(String(format: "~%.1f kWh · %@", device.energyKwh, device.controllable ? "wallbox" : "appliance"))
                    .font(.caption).foregroundStyle(Theme.subtle)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private func bestTime(_ r: OptimizeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("best time").font(.caption).foregroundStyle(Theme.subtle)
            Text(prettyWindow(r)).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
            HStack(spacing: 6) {
                Image(systemName: Source(r.source) == .free ? "sun.max.fill" : Source(r.source) == .partial ? "cloud.sun.fill" : "bolt.fill")
                Text(sourcePhrase(r)).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Theme.source(r.source))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.sourceSoft(r.source), in: Capsule())
        }
    }

    private func ribbon(_ r: OptimizeResult) -> some View {
        let (sh, eh) = windowHours(r)
        return VStack(alignment: .leading, spacing: 6) {
            Text("where the energy comes from, across today").font(.caption).foregroundStyle(Theme.subtle)
            HStack(spacing: 2) {
                ForEach(r.ribbon) { cell in
                    let h = Int(cell.hour.prefix(2)) ?? 0
                    let inWindow = h >= sh && h < eh
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.source(cell.source).opacity(inWindow ? 1 : 0.45))
                        .frame(height: 30)
                        .overlay(inWindow ? RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.ink.opacity(0.55), lineWidth: 1.5) : nil)
                }
            }
            HStack { Text("00"); Spacer(); Text("06"); Spacer(); Text("12"); Spacer(); Text("18"); Spacer(); Text("24") }
                .font(.system(size: 10)).foregroundStyle(Theme.subtle)
            HStack(spacing: 14) {
                legend(.free); legend(.partial); legend(.paid)
            }.padding(.top, 2)
        }
    }

    private func legend(_ s: Source) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Theme.source(s.rawValue)).frame(width: 8, height: 8)
            Text(Theme.sourceLabel(s.rawValue)).font(.system(size: 11)).foregroundStyle(Theme.subtle)
        }
    }

    private func metrics(_ r: OptimizeResult) -> some View {
        HStack(spacing: 10) {
            metric("your share", "\(Int(r.ownSharePct))%")
            metric("grid cost", String(format: "€%.2f", r.gridCostEur))
        }
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(Theme.subtle)
            Text(value).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Theme.ink)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(16)
    }

    private func confirm(_ r: OptimizeResult) -> some View {
        VStack(spacing: 8) {
            Button {
                Task { if await vm.commit() { await onCommit(); dismiss() } }
            } label: {
                HStack {
                    if vm.committing { ProgressView().tint(.white) }
                    Text(vm.committing ? "Scheduling…" : "Schedule it").font(.system(.headline, design: .rounded))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(vm.committing)
            Label(device.controllable
                  ? "We’ll start it for you at the chosen time."
                  : "We’ll remind you to start it — no auto-control on this appliance.",
                  systemImage: device.controllable ? "wand.and.stars" : "bell")
                .font(.caption2).foregroundStyle(Theme.subtle)
        }
    }

    // helpers
    private var symbol: String {
        switch device.icon { case "car": return "car.fill"; case "bowl": return "dishwasher.fill"; case "wash": return "washer.fill"; default: return "powerplug.fill" }
    }
    private func prettyWindow(_ r: OptimizeResult) -> String { "Today, \(r.window)" }
    private func windowHours(_ r: OptimizeResult) -> (Int, Int) {
        let sh = Int(r.start.dropFirst(11).prefix(2)) ?? 0
        var eh = Int(r.end.dropFirst(11).prefix(2)) ?? sh
        if eh <= sh { eh = sh + 1 }
        return (sh, eh)
    }
    private func sourcePhrase(_ r: OptimizeResult) -> String {
        switch Source(r.source) {
        case .free: return "Free — your solar covers it"
        case .partial: return "\(Int(r.ownSharePct))% yours, rest cheap grid"
        case .paid: return "All from the grid"
        }
    }
}
