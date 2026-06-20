import SwiftUI

/// The live power flow — reached by tapping the verdict (kept off the calm home surface).
struct FlowDetailView: View {
    let state: EnergyState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Right now").font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(Theme.subtle) }
            }
            HStack(spacing: 14) {
                Label(String(format: "%.0f°C", state.outdoorTempC), systemImage: "thermometer.medium")
                Label(String(format: "€%.2f/kWh", state.priceEurPerKwh), systemImage: "eurosign.circle")
            }.font(.footnote.weight(.medium)).foregroundStyle(Theme.subtle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                pill("sun.max.fill", "Solar", state.solarKw, "producing", Theme.amber)
                pill("house.fill", "Home", state.consumptionKw, "using", Theme.green)
                pill("minus.plus.batteryblock.fill", "Battery", abs(state.battery.flowKw),
                     "\(Int(state.battery.socPct))% · \(state.battery.state)", Theme.greenDeep)
                pill("bolt.fill", "Grid", abs(state.grid.flowKw), state.grid.direction, Theme.grid)
            }

            HStack {
                Text("Net flow").font(.subheadline).foregroundStyle(Theme.subtle)
                Spacer()
                Text(String(format: "%+.1f kW", state.netKw)).font(.title3.weight(.bold))
                    .foregroundStyle(state.netKw >= 0 ? Theme.green : Theme.grid)
            }
            .padding(14).cardSurface(14)
            Spacer()
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .warmScreen()
        .presentationDetents([.medium, .large])
    }

    private func pill(_ icon: String, _ title: String, _ value: Double, _ sub: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icon).foregroundStyle(tint); Text(title).font(.subheadline.weight(.semibold)) }
            (Text(String(format: "%.2f", value)).font(.title2.weight(.bold)) + Text(" kW").font(.subheadline).foregroundStyle(Theme.subtle))
                .foregroundStyle(Theme.ink)
            Text(sub).font(.caption).foregroundStyle(Theme.subtle)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(16)
    }
}
