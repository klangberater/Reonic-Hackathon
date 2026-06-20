import SwiftUI

struct NowView: View {
    @StateObject private var vm = NowViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let s = vm.state {
                    heroCard(s)
                    flowSection(s)
                    metricsRow(s)
                } else if vm.isLoading {
                    ProgressView("Reading your home…")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let err = vm.errorText {
                    errorCard(err)
                }
            }
            .padding(20)
        }
        .background(Theme.bg.ignoresSafeArea())
        .refreshable { await vm.load() }
        .task { if vm.state == nil { await vm.load() } }
    }

    // MARK: header + clock toggle
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lumen").font(.largeTitle.bold())
                Spacer()
                if let s = vm.state {
                    Text(s.householdName).font(.subheadline).foregroundStyle(Theme.subtle)
                }
            }
            Picker("Clock", selection: Binding(get: { vm.clock }, set: { vm.setClock($0) })) {
                ForEach(DemoClock.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: hero verdict
    private func heroCard(_ s: EnergyState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(statusTitle(s.status).uppercased())
                .font(.caption.bold())
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.85))
            Text(vm.verdict)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                Label(prettyTime(s.at), systemImage: "clock")
                Label(String(format: "%.0f°C", s.outdoorTempC), systemImage: "thermometer.medium")
                Label(String(format: "€%.2f/kWh", s.priceEurPerKwh), systemImage: "eurosign.circle")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.statusGradient(s.status), in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
    }

    // MARK: power flow
    private func flowSection(_ s: EnergyState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Power flow").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FlowPill(icon: "sun.max.fill", title: "Solar", value: s.solarKw,
                         sub: s.solarKw > 0.05 ? "producing" : "off", tint: Theme.amber, direction: .out)
                FlowPill(icon: "house.fill", title: "Home", value: s.consumptionKw,
                         sub: "using", tint: Theme.green, direction: .in)
                FlowPill(icon: "minus.plus.batteryblock.fill", title: "Battery",
                         value: abs(s.battery.flowKw), sub: "\(Int(s.battery.socPct))% · \(s.battery.state)",
                         tint: Theme.greenDeep, direction: s.battery.flowKw > 0.05 ? .in : (s.battery.flowKw < -0.05 ? .out : .none))
                FlowPill(icon: "bolt.fill", title: "Grid", value: abs(s.grid.flowKw),
                         sub: s.grid.direction, tint: Theme.grid,
                         direction: s.grid.direction == "exporting" ? .out : (s.grid.direction == "importing" ? .in : .none))
            }
        }
    }

    // MARK: metric tiles
    private func metricsRow(_ s: EnergyState) -> some View {
        HStack(spacing: 12) {
            MetricTile(icon: "leaf.fill", label: "Self-powered",
                       value: s.status == "drawing_grid" ? "Partly" : "Yes", tint: Theme.green)
            MetricTile(icon: "arrow.up.right", label: "Net flow",
                       value: String(format: "%+.1f kW", s.netKw), tint: s.netKw >= 0 ? Theme.green : Theme.grid)
        }
    }

    private func errorCard(_ err: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(Theme.subtle)
            Text("Couldn’t reach Lumen").font(.headline)
            Text(err).font(.footnote).foregroundStyle(Theme.subtle).multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.load() } }.buttonStyle(.borderedProminent).tint(Theme.green)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding()
    }

    // helpers
    private func statusTitle(_ s: String) -> String {
        switch s {
        case "exporting_surplus": return "Surplus → grid"
        case "drawing_grid": return "Drawing from grid"
        default: return "Self-powered"
        }
    }
    private func prettyTime(_ iso: String) -> String {
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"; inF.locale = Locale(identifier: "en_US_POSIX")
        guard let d = inF.date(from: iso) else { return iso }
        let outF = DateFormatter(); outF.dateFormat = "EEE d MMM · HH:mm"
        return outF.string(from: d)
    }
}

// MARK: - Components

private struct FlowPill: View {
    enum Direction { case `in`, out, none }
    let icon: String
    let title: String
    let value: Double
    let sub: String
    let tint: Color
    let direction: Direction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                if direction != .none {
                    Image(systemName: direction == .out ? "arrow.up.right" : "arrow.down.left")
                        .font(.caption.bold())
                        .foregroundStyle(direction == .out ? Theme.green : Theme.grid)
                }
            }
            Text(String(format: "%.2f", value)) .font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
            + Text(" kW").font(.subheadline).foregroundStyle(Theme.subtle)
            Text(sub).font(.caption).foregroundStyle(Theme.subtle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct MetricTile: View {
    let icon: String
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text(label).font(.caption).foregroundStyle(Theme.subtle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}
