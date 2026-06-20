import SwiftUI

/// Lightweight settings sheet: the demo clock (summer/winter) and appearance.
/// Bound to the shared `ClockStore` so both Home and Plan-my-day can present it.
struct SettingsView: View {
    @ObservedObject var clock: ClockStore
    @AppStorage("appearance") private var appearance = "dark"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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
                    Text("Switches the home's “now”. Live tracks the real clock; Sunny demo pins a bright midday so plans land on solar; Winter surfaces the heat-pump anomaly.")
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
        }
    }
}
