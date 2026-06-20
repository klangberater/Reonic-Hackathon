import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @State private var selectedDevice: Device?
    @State private var showFlow = false
    @State private var showChat = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if vm.state != nil {
                    statusIndicator
                    verdictHero
                    moneyCard
                    devicesSection
                    ForEach(vm.proactiveCards) { proactiveCard($0) }
                } else if vm.isLoading {
                    ProgressView("Reading your home…").frame(maxWidth: .infinity, minHeight: 280)
                } else if let err = vm.errorText {
                    errorCard(err)
                }
            }
            .padding(20)
            .padding(.bottom, 76)
        }
        .warmScreen()
        .safeAreaInset(edge: .bottom) { askBar }
        .refreshable { await vm.loadAll() }
        .task { if vm.state == nil { await vm.loadAll() } }
        .sheet(item: $selectedDevice) { d in
            DeviceSheetView(device: d, clock: vm.clock) { await vm.reloadDevices() }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showFlow) { if let s = vm.state { FlowDetailView(state: s) } }
        .sheet(isPresented: $showChat) { ChatView(clock: vm.clock) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lumen").font(.system(.largeTitle, design: .rounded).weight(.bold)).foregroundStyle(Theme.ink)
                    if let s = vm.state { Text("\(greeting), \(firstName(s.householdName))").font(.subheadline).foregroundStyle(Theme.subtle) }
                }
                Spacer()
                Image(systemName: "sun.max.fill").font(.title2).foregroundStyle(Theme.amber)
            }
            Picker("Clock", selection: Binding(get: { vm.clock }, set: { vm.setClock($0) })) {
                ForEach(DemoClock.allCases) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented)
        }
    }

    @ViewBuilder private var statusIndicator: some View {
        if let a = vm.activeAnomaly {
            VStack(alignment: .leading, spacing: 8) {
                Label("Needs a look", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold()).foregroundStyle(Theme.red)
                Text(a.title).font(.system(.headline, design: .rounded)).foregroundStyle(Theme.ink)
                Text(a.detail).font(.subheadline).foregroundStyle(Theme.subtle).fixedSize(horizontal: false, vertical: true)
                Text(a.suggestedAction).font(.footnote.weight(.medium)).foregroundStyle(Theme.red)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.redSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.red.opacity(0.35), lineWidth: 1))
        } else {
            HStack(spacing: 7) {
                Circle().fill(Theme.green).frame(width: 8, height: 8)
                Text("All good").font(.subheadline.weight(.medium)).foregroundStyle(Theme.green)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Theme.greenSoft, in: Capsule())
        }
    }

    private var verdictHero: some View {
        Button { showFlow = true } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: heroIcon).font(.title2).foregroundStyle(Theme.green)
                Text(vm.verdict).font(.system(.title2, design: .rounded).weight(.semibold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.subtle).padding(.top, 7)
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.greenSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }.buttonStyle(.plain)
    }

    private var moneyCard: some View {
        HStack(spacing: 14) {
            ZStack { Circle().fill(Theme.amberSoft).frame(width: 44, height: 44)
                Image(systemName: "eurosign").font(.headline).foregroundStyle(Theme.amber) }
            VStack(alignment: .leading, spacing: 2) {
                Text("forecast · this month").font(.caption).foregroundStyle(Theme.subtle)
                Text(vm.moneyLine).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Theme.ink)
            }
            Spacer()
        }
        .padding(16).cardSurface()
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What do you want to run?").font(.system(.headline, design: .rounded)).foregroundStyle(Theme.ink)
            ForEach(vm.devices) { d in
                Button { selectedDevice = d } label: { DeviceRow(device: d) }.buttonStyle(.plain)
            }
        }
    }

    private func proactiveCard(_ e: InsightEvent) -> some View {
        HStack(spacing: 12) {
            ZStack { Circle().fill(Theme.greenSoft).frame(width: 38, height: 38)
                Image(systemName: e.type == "nudge" ? "lightbulb.fill" : "chart.line.uptrend.xyaxis").foregroundStyle(Theme.green) }
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(e.suggestedAction).font(.caption).foregroundStyle(Theme.subtle)
            }
            Spacer()
        }
        .padding(14).cardSurface()
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
            .overlay(Capsule().strokeBorder(Theme.hairline.opacity(0.6), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 8)
        }.buttonStyle(.plain)
    }

    private func errorCard(_ err: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(Theme.subtle)
            Text("Couldn’t reach Lumen").font(.system(.headline, design: .rounded))
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
        HStack(spacing: 12) {
            ZStack { Circle().fill(tint.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(tint) }
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(Theme.ink)
                if let s = device.scheduled {
                    Text("\(s.window) · \(Theme.sourceLabel(s.source))").font(.caption.weight(.medium)).foregroundStyle(Theme.source(s.source))
                } else {
                    Text("tap to plan").font(.caption).foregroundStyle(Theme.subtle)
                }
            }
            Spacer()
            Image(systemName: device.status == "scheduled" ? "checkmark.circle.fill" : "chevron.right")
                .font(.footnote.weight(.semibold)).foregroundStyle(device.status == "scheduled" ? Theme.green : Theme.subtle)
        }
        .padding(14).cardSurface(18)
    }
    private var tint: Color {
        switch device.icon { case "car": return Theme.green; case "bowl": return Theme.amber; case "wash": return Theme.grid; default: return Theme.green }
    }
    private var symbol: String {
        switch device.icon { case "car": return "car.fill"; case "bowl": return "dishwasher.fill"; case "wash": return "washer.fill"; default: return "powerplug.fill" }
    }
}
