import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MuesliAppModel

    private var recordingRequirements: [SetupRequirement] {
        model.requirements.filter { $0.blocksManualRecording }
    }

    private var featureRequirements: [SetupRequirement] {
        model.requirements.filter { !$0.blocksManualRecording }
    }

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

            Section("Recording Readiness") {
                Label(
                    model.canRecordManually ? "Manual recording is ready." : "Recording is blocked until the items below are fixed.",
                    systemImage: model.canRecordManually ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(model.canRecordManually ? .green : .orange)

                ForEach(recordingRequirements) { requirement in
                    RequirementRow(requirement: requirement)
                }
            }

            Section("Automation & Transcripts") {
                Text("These items improve automatic meeting detection and first-run transcription, but they do not block manual recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(featureRequirements) { requirement in
                    RequirementRow(requirement: requirement)
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

private struct RequirementRow: View {
    let requirement: SetupRequirement

    var body: some View {
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
}
