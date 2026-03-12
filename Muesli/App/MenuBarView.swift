import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: MuesliAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            meetingSummary
            upcomingMeetingsSection
            setupSummary

            Divider()

            VStack(spacing: 6) {
                MenuActionButton(
                    title: model.activeSession == nil ? "Start Now" : "Stop Recording",
                    systemImage: model.activeSession == nil ? "record.circle" : "stop.circle",
                    enabled: model.activeSession != nil || model.canRecordManually
                ) {
                    if model.activeSession == nil {
                        model.manualStart()
                    } else {
                        model.stopRecording()
                    }
                }

                MenuActionButton(
                    title: "Open Latest Transcript",
                    systemImage: "text.document",
                    enabled: model.sessions.contains(where: { $0.transcript != nil })
                ) {
                    model.openLatestTranscript()
                }

                MenuActionButton(
                    title: "Open Latest Folder",
                    systemImage: "folder",
                    enabled: !model.sessions.isEmpty
                ) {
                    model.openLatestFolder()
                }

                MenuActionButton(
                    title: "History",
                    systemImage: "clock.arrow.circlepath",
                    enabled: true
                ) {
                    presentWindow(id: "history")
                }

                MenuActionButton(
                    title: "Settings",
                    systemImage: "gearshape",
                    enabled: true
                ) {
                    presentWindow(id: "settings")
                }
            }

            Divider()

            MenuActionButton(
                title: "Quit",
                systemImage: "power",
                enabled: true,
                tint: .red
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Muesli")
                    .font(.title3.weight(.semibold))
                Text(statusCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(model.status.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.12), in: Capsule())
        }
    }

    @ViewBuilder
    private var meetingSummary: some View {
        if let activeSession = model.activeSession {
            SummaryCard(
                title: activeSession.title,
                subtitle: "Started \(DateFormatters.shortDateTime.string(from: activeSession.startedAt ?? .now))",
                tint: .red
            )
        }
    }

    @ViewBuilder
    private var upcomingMeetingsSection: some View {
        if !model.upcomingTodayMeetings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(model.upcomingTodayMeetings) { meeting in
                        UpcomingMeetingRow(meeting: meeting)
                    }
                }
            }
        } else if model.activeSession == nil, let nextMeeting = model.armedMeetings.first {
            SummaryCard(
                title: nextMeeting.candidate.title,
                subtitle: "Armed for \(DateFormatters.shortDateTime.string(from: nextMeeting.candidate.startDate))",
                tint: .orange
            )
        }
    }

    @ViewBuilder
    private var setupSummary: some View {
        if !model.missingRecordingRequirements.isEmpty {
            SummaryCard(
                title: "Setup Needed To Record",
                subtitle: model.missingRecordingRequirements.map(\.title).joined(separator: ", "),
                tint: .orange
            )
        } else if !model.missingFeatureRequirements.isEmpty {
            SummaryCard(
                title: "Manual Recording Is Ready",
                subtitle: "Optional setup remaining: \(model.missingFeatureRequirements.map(\.title).joined(separator: ", "))",
                tint: .blue
            )
        }
    }

    private var statusCaption: String {
        if !model.missingRecordingRequirements.isEmpty {
            return "Recording permissions still need attention."
        }

        if !model.missingFeatureRequirements.isEmpty {
            return "Manual capture is ready. Some automatic features are still limited."
        }

        return "Ready for the next meeting."
    }

    private func presentWindow(id: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: id)
    }

    private var statusColor: Color {
        switch model.status {
        case .idle:
            .green
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

private struct SummaryCard: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct UpcomingMeetingRow: View {
    let meeting: UpcomingMeetingSummary

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(DateFormatters.shortTime.string(from: meeting.startDate))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(meeting.detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct MenuActionButton: View {
    let title: String
    let systemImage: String
    let enabled: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(enabled ? (isHovered ? tint : .primary) : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundStyle)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .onHover { hovering in
            isHovered = enabled && hovering
        }
    }

    private var backgroundStyle: some ShapeStyle {
        if isHovered {
            return AnyShapeStyle(tint.opacity(0.16))
        }

        return AnyShapeStyle(Color.primary.opacity(0.04))
    }

    private var borderColor: Color {
        if isHovered {
            return tint.opacity(0.22)
        }

        return Color.primary.opacity(0.06)
    }
}
