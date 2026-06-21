import SwiftUI

/// Lightweight settings sheet: the demo clock (summer/winter) and appearance.
/// Bound to the shared `ClockStore` so both Home and Plan-my-day can present it.
struct SettingsView: View {
    @ObservedObject var clock: ClockStore
    @AppStorage("appearance") private var appearance = "dark"
    @Environment(\.dismiss) private var dismiss
    @State private var contract: Contract?

    var body: some View {
        NavigationStack {
            Form {
                if let c = contract { contractSection(c) }

                Section {
                    Picker("Time", selection: Binding(
                        get: { clock.clock },
                        set: { clock.setClock($0) }
                    )) {
                        ForEach(DemoClock.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Demo clock")
                } footer: {
                    Text("Switches the home's “now”. Winter surfaces the heat-pump anomaly; summer is the sunny demo day.")
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task(id: clock.clock) { contract = try? await APIClient().contract(clock: clock.clock) }
        }
    }

    // The contract surfaced for the customer: tariff, renewal deadline, feed-in (the lever
    // behind "money earned"), and the full terms — fields the rest of the app doesn't use.
    @ViewBuilder private func contractSection(_ c: Contract) -> some View {
        Section {
            LabeledContent("Tariff", value: c.tariffName)
            LabeledContent("Term ends", value: prettyDate(c.contractEnd))
            LabeledContent("Give notice by", value: prettyDate(c.noticeByDate))
            LabeledContent("Feed-in", value: String(format: "€%.3f / kWh", c.feedInEurPerKwh))
            LabeledContent("Monthly fee", value: String(format: "€%.2f", c.baseFeeEurPerMonth))
            DisclosureGroup("Full terms") {
                Text(c.termsText).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Your contract")
        } footer: {
            Text(c.inNoticeWindow
                 ? "You're inside the \(c.noticePeriodWeeks)-week notice window — give notice by \(prettyDate(c.noticeByDate)) or it auto-renews for \(c.autoRenewMonths) months."
                 : "Auto-renews for \(c.autoRenewMonths) months unless you give notice — \(c.daysUntilNoticeDeadline) days until the deadline.")
        }
    }

    private func prettyDate(_ ymd: String) -> String {
        let inF = DateFormatter(); inF.dateFormat = "yyyy-MM-dd"; inF.locale = Locale(identifier: "en_US_POSIX")
        guard let d = inF.date(from: ymd) else { return ymd }
        let outF = DateFormatter(); outF.dateFormat = "d MMM yyyy"; outF.locale = Locale(identifier: "en_US_POSIX")
        return outF.string(from: d)
    }
}
