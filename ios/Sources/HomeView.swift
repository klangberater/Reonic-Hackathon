import SwiftUI

struct HomeView: View {
    @StateObject private var vm: HomeViewModel
    init(clock: ClockStore) { _vm = StateObject(wrappedValue: HomeViewModel(clockStore: clock)) }
    @State private var selectedDevice: Device?
    @State private var showFlow = false
    @State private var showChat = false
    @State private var chatSeed: String?
    @State private var showSettings = false

    var body: some View {
        Group {
            if vm.state != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        anomalyCard
                        verdictLine
                        devicesSection
                        moneyCard
                    }
                    .padding(20)
                }
            } else if vm.isLoading {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    Spacer(); ProgressView("Reading your home…").frame(maxWidth: .infinity); Spacer()
                }
                .padding(20)
            } else if let err = vm.errorText {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    Spacer(); errorCard(err); Spacer()
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .warmScreen()
        .safeAreaInset(edge: .bottom) { askBar }
        .task { if vm.state == nil { await vm.loadAll() } }
        .onAppear { Task { await vm.reloadDevices() } }
        .sheet(item: $selectedDevice) { d in
            DeviceSheetView(device: d, clock: vm.clock) { await vm.reloadDevices() }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showFlow) { if let s = vm.state { FlowDetailView(state: s) } }
        .sheet(isPresented: $showChat, onDismiss: { chatSeed = nil }) { ChatView(clock: vm.clock, initialPrompt: chatSeed) }
        .sheet(isPresented: $showSettings) { SettingsView(vm: vm).presentationDetents([.medium]) }
    }

    // Header: title + greeting (left), health status (right, where the sun was)
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lumen").font(.system(.largeTitle).weight(.bold)).foregroundStyle(Theme.ink)
                if let s = vm.state { Text("\(greeting), \(firstName(s.householdName))").font(.subheadline).foregroundStyle(Theme.subtle) }
            }
            Spacer()
            HStack(spacing: 12) {
                PagerDots(current: 0)
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").font(.title3).foregroundStyle(Theme.subtle)
                }
                .accessibilityLabel("Settings")
                statusChip
            }
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

    // Detailed anomaly card — only when health is in alert
    @ViewBuilder private var anomalyCard: some View {
        if let a = vm.activeAnomaly {
            Button {
                chatSeed = "Why is my heat pump using so much?"
                showChat = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Needs a look", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold()).foregroundStyle(Theme.red)
                    Text(a.title).font(.system(.headline)).foregroundStyle(Theme.ink)
                    Text(a.detail).font(.subheadline).foregroundStyle(Theme.subtle).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(a.suggestedAction).font(.footnote.weight(.medium)).foregroundStyle(Theme.red)
                        Spacer(minLength: 4)
                        Image(systemName: "sparkles").font(.caption2).foregroundStyle(Theme.red)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.redSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.red.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // Verdict: small, informative line (tap for the live flow)
    private var verdictLine: some View {
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

    // The focal point
    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What do you want to do?").font(.system(.title2).weight(.bold)).foregroundStyle(Theme.ink)
            ForEach(vm.devices) { d in
                Button { selectedDevice = d } label: { DeviceRow(device: d) }.buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private var moneyCard: some View {
        HStack(spacing: 9) {
            Image(systemName: "eurosign.circle.fill").font(.subheadline).foregroundStyle(Theme.amber)
            Text(vm.moneyLine).font(.footnote.weight(.medium)).foregroundStyle(Theme.subtle)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10).cardSurface(14)
    }

    private var askBar: some View {
        Button { showChat = true } label: {
            HStack(spacing: 9) {
                Image(systemName: "sparkles").foregroundStyle(Theme.green)
                Text("Ask anything…").foregroundStyle(Theme.subtle)
                Spacer()
                Image(systemName: "mic.fill").foregroundStyle(Theme.subtle)
            }
            .font(.callout)
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 8)
        }.buttonStyle(.plain)
    }

    private func errorCard(_ err: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(Theme.subtle)
            Text("Couldn’t reach Lumen").font(.system(.headline))
            Text(err).font(.footnote).foregroundStyle(Theme.subtle).multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.loadAll() } }.buttonStyle(.borderedProminent).tint(Theme.green)
        }.frame(maxWidth: .infinity, minHeight: 260).padding()
    }

    // helpers
    private var heroIcon: String {
        switch vm.state?.status {
        case "exporting_surplus": return "sun.max.fill"
        case "drawing_grid": return "bolt.fill"
        default: return "leaf.fill"
        }
    }
    private var greeting: String {
        let h = Int(vm.state?.at.dropFirst(11).prefix(2) ?? "12") ?? 12
        return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
    private func firstName(_ name: String) -> String { name.components(separatedBy: " ").last ?? name }
}

struct DeviceRow: View {
    let device: Device
    var body: some View {
        HStack(spacing: 16) {
            ZStack { Circle().fill(tint.opacity(0.15)).frame(width: 54, height: 54)
                Image(systemName: symbol).font(.system(size: 25)).foregroundStyle(tint) }
            VStack(alignment: .leading, spacing: 3) {
                Text(device.displayName).font(.system(.title3).weight(.semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if let s = device.scheduled {
                    Text("\(s.window) · \(Theme.sourceLabel(s.source))").font(.subheadline.weight(.medium)).foregroundStyle(Theme.source(s.source))
                } else {
                    Text("tap to plan").font(.subheadline).foregroundStyle(Theme.subtle)
                }
            }
            Spacer()
            Image(systemName: device.status == "scheduled" ? "checkmark.circle.fill" : "chevron.right")
                .font(.body.weight(.semibold)).foregroundStyle(device.status == "scheduled" ? Theme.green : Theme.subtle)
        }
        .padding(.horizontal, 18).padding(.vertical, 18).cardSurface(20)
    }
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
}
