import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @State private var selectedDevice: Device?
    @State private var showFlow = false
    @State private var showChat = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if vm.state != nil {
                    statusIndicator
                    verdict
                    moneyCard
                    devicesSection
                    ForEach(vm.proactiveCards) { proactiveCard($0) }
                } else if vm.isLoading {
                    ProgressView("Reading your home…").frame(maxWidth: .infinity, minHeight: 260)
                } else if let err = vm.errorText {
                    errorCard(err)
                }
            }
            .padding(20)
            .padding(.bottom, 70)
        }
        .background(Theme.bg.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lumen").font(.largeTitle.bold())
                Spacer()
                if let s = vm.state { Text(s.householdName).font(.subheadline).foregroundStyle(Theme.subtle) }
            }
            Picker("Clock", selection: Binding(get: { vm.clock }, set: { vm.setClock($0) })) {
                ForEach(DemoClock.allCases) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented)
        }
    }

    @ViewBuilder private var statusIndicator: some View {
        if let a = vm.activeAnomaly {
            VStack(alignment: .leading, spacing: 8) {
                Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold()).foregroundStyle(Theme.red)
                Text(a.title).font(.headline)
                Text(a.detail).font(.subheadline).foregroundStyle(Theme.subtle).fixedSize(horizontal: false, vertical: true)
                Text(a.suggestedAction).font(.footnote.weight(.medium)).foregroundStyle(Theme.red)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.red.opacity(0.4), lineWidth: 1))
        } else {
            Label("All good", systemImage: "circle.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.green)
                .labelStyle(DotLabel())
        }
    }

    private var verdict: some View {
        Button { showFlow = true } label: {
            HStack(alignment: .top) {
                Text(vm.verdict).font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Theme.subtle).padding(.top, 6)
            }
        }.buttonStyle(.plain)
    }

    private var moneyCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("forecast · this month").font(.caption).foregroundStyle(Theme.subtle)
            Text(vm.moneyLine).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What do you want to run?").font(.headline)
            ForEach(vm.devices) { d in
                Button { selectedDevice = d } label: { DeviceRow(device: d) }.buttonStyle(.plain)
            }
        }
    }

    private func proactiveCard(_ e: InsightEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: e.type == "nudge" ? "lightbulb.fill" : "chart.line.uptrend.xyaxis")
                .foregroundStyle(Theme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.subheadline.weight(.semibold))
                Text(e.suggestedAction).font(.caption).foregroundStyle(Theme.subtle)
            }
            Spacer()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private var askBar: some View {
        Button { showChat = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Theme.green)
                Text("Ask anything…").foregroundStyle(Theme.subtle)
                Spacer()
                Image(systemName: "mic.fill").foregroundStyle(Theme.subtle)
            }
            .font(.callout)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.subtle.opacity(0.25)))
            .padding(.horizontal, 20).padding(.bottom, 6)
        }.buttonStyle(.plain)
    }

    private func errorCard(_ err: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(Theme.subtle)
            Text("Couldn’t reach Lumen").font(.headline)
            Text(err).font(.footnote).foregroundStyle(Theme.subtle).multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.loadAll() } }.buttonStyle(.borderedProminent).tint(Theme.green)
        }.frame(maxWidth: .infinity, minHeight: 240).padding()
    }
}

private struct DotLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) { configuration.icon.font(.system(size: 9)); configuration.title }
    }
}

struct DeviceRow: View {
    let device: Device
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(Theme.subtle).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                if let s = device.scheduled {
                    Text("\(s.window) · \(Theme.sourceLabel(s.source))").font(.caption).foregroundStyle(Theme.source(s.source))
                } else {
                    Text("tap to plan").font(.caption).foregroundStyle(Theme.subtle)
                }
            }
            Spacer()
            Image(systemName: device.status == "scheduled" ? "checkmark.circle.fill" : "chevron.right")
                .font(.footnote).foregroundStyle(device.status == "scheduled" ? Theme.green : Theme.subtle)
        }
        .padding(12).frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
    private var symbol: String {
        switch device.icon {
        case "car": return "car.fill"
        case "bowl": return "dishwasher.fill"
        case "wash": return "washer.fill"
        default: return "powerplug.fill"
        }
    }
}
