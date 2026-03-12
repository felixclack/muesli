import SwiftUI

struct HistoryWindowView: View {
    @ObservedObject var model: MuesliAppModel

    var body: some View {
        List(model.sessions) { session in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(session.title)
                        .font(.headline)
                    Spacer()
                    Text(session.state.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(DateFormatters.shortDateTime.string(from: session.startedAt ?? session.scheduledStart))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Open Folder") {
                        model.openSessionFolder(session)
                    }
                    .buttonStyle(.link)

                    if session.transcript != nil {
                        Button("Open Transcript") {
                            model.openSessionTranscript(session)
                        }
                        .buttonStyle(.link)
                    } else if session.artifacts.mixedAudioPath != nil {
                        Button("Retry Transcript") {
                            model.retryTranscription(for: session)
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minWidth: 640, minHeight: 360)
    }
}
