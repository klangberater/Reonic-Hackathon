import SwiftUI

/// Lightweight settings sheet: the demo clock (summer/winter) and appearance.
struct SettingsView: View {
    @ObservedObject var vm: HomeViewModel
    @AppStorage("appearance") private var appearance = "dark"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Time", selection: Binding(
                        get: { vm.clock },
                        set: { vm.setClock($0) }
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
        }
    }
}
