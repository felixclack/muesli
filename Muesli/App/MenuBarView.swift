import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: MuesliAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muesli")
                .font(.headline)
            HStack {
                Text("Status")
                Spacer()
                Text(model.status.title)
                    .foregroundStyle(statusColor)
            }

            if let activeSession = model.activeSession {
                Text(activeSession.title)
                    .font(.subheadline)
                Text("Started \(DateFormatters.shortDateTime.string(from: activeSession.startedAt ?? .now))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let nextMeeting = model.armedMeetings.first {
                Text(nextMeeting.candidate.title)
                    .font(.subheadline)
                Text("Armed for \(DateFormatters.shortDateTime.string(from: nextMeeting.candidate.startDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !model.requirements.allSatisfy(\.satisfied) {
                Divider()
                Text("Setup Needed")
                    .font(.subheadline.weight(.medium))
                ForEach(model.requirements.filter { !$0.satisfied }) { requirement in
                    Text("• \(requirement.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button(model.activeSession == nil ? "Start Now" : "Stop Recording") {
                if model.activeSession == nil {
                    model.manualStart()
                } else {
                    model.stopRecording()
                }
            }

            Button("Open Latest Transcript") {
                model.openLatestTranscript()
            }
            .disabled(!model.sessions.contains(where: { $0.transcript != nil }))

            Button("Open Latest Folder") {
                model.openLatestFolder()
            }
            .disabled(model.sessions.isEmpty)

            Button("History") {
                openWindow(id: "history")
            }

            SettingsLink {
                Text("Settings")
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 320)
    }

    private var statusColor: Color {
        switch model.status {
        case .idle:
            .secondary
        case .armed:
            .orange
        case .recording:
            .red
        case .transcribing:
            .blue
        case .needsSetup:
            .yellow
        case .failed:
            .red
        case .conflict:
            .orange
        }
    }
}
