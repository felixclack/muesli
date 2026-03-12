import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MuesliAppModel

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.settingsStore.settings.launchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                ))

                TextField("Gather bundle identifier", text: Binding(
                    get: { model.settingsStore.settings.gatherBundleIdentifier },
                    set: { model.settingsStore.settings.gatherBundleIdentifier = $0 }
                ))

                TextField("Gather process name", text: Binding(
                    get: { model.settingsStore.settings.gatherProcessName },
                    set: { model.settingsStore.settings.gatherProcessName = $0 }
                ))
            }

            Section("Setup") {
                ForEach(model.requirements) { requirement in
                    HStack(alignment: .top) {
                        Image(systemName: requirement.satisfied ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(requirement.satisfied ? .green : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(requirement.title)
                                .font(.headline)
                            Text(requirement.instructions)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button("Grant Permissions & Download Model") {
                    model.requestPermissionsAndModel()
                }
            }

            if let lastError = model.lastError {
                Section("Last Error") {
                    Text(lastError)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .frame(width: 560)
    }
}
