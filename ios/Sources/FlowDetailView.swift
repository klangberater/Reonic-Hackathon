import SwiftUI

/// The live power flow — reached by tapping the verdict (kept off the calm home surface).
struct FlowDetailView: View {
    let state: EnergyState
    var money: Money? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var detent: PresentationDetent = .large   // open expanded so all content shows

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Right now").font(.system(.title2).weight(.bold)).foregroundStyle(Theme.ink)
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
                    pill("bolt.fill", "Grid", abs(state.grid.flowKw), gridSub, Theme.grid)
                }

                HStack {
                    Text("Net flow").font(.subheadline).foregroundStyle(Theme.subtle)
                    Spacer()
                    Text(String(format: "%+.1f kW", state.netKw)).font(.title3.weight(.bold))
                        .foregroundStyle(state.netKw >= 0 ? Theme.green : Theme.grid)
                }
                .padding(14).cardSurface(14)

                monthSection
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .warmScreen()
        .presentationDetents([.medium, .large], selection: $detent)
    }

    // The month-end forecast — carried over from the (now hidden) Home screen.
    @ViewBuilder private var monthSection: some View {
        if let m = money {
            let toDate = m.costToDateEur < 0
                ? "€\(String(format: "%.0f", -m.costToDateEur)) in credit"
                : "€\(String(format: "%.0f", m.costToDateEur)) spent"
            let explain = m.earning
                ? "Your solar feed-in, minus the grid power you buy back and fees."
                : "Your grid power and fees, minus your solar feed-in."
            VStack(alignment: .leading, spacing: 12) {
                Text("This month").font(.headline).foregroundStyle(Theme.ink)
                HStack(spacing: 12) {
                    moneyTile(m.earning ? "arrow.down.left.circle.fill" : "eurosign.circle.fill",
                              m.earning ? "Net — on track to earn" : "Net — projected bill",
                              "€\(abs(Int(m.projectedTotalEur.rounded())))",
                              m.earning ? Theme.green : Theme.amber)
                    moneyTile("sun.max.fill", "Solar sold to grid",
                              "€\(Int(m.earnedFromSolarEur.rounded()))", Theme.amber)
                }
                Text("\(explain) \(toDate) so far \u{00B7} day \(m.daysElapsed) of \(m.daysInMonth).")
                    .font(.caption).foregroundStyle(Theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
    }

    // "balanced" (≈0 grid flow) reads as jargon — say it plainly.
    private var gridSub: String {
        state.grid.direction == "balanced" ? "not using the grid" : state.grid.direction
    }

    private func moneyTile(_ icon: String, _ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(value).font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface(16)
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
