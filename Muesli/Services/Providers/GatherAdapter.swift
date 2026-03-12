import AppKit
import Foundation

actor GatherAdapter: MeetingProviderAdapter {
    nonisolated let provider: MeetingProviderKind = .gather

    nonisolated func supports(_ link: MeetingLink) -> Bool {
        link.provider == .gather
    }

    func pollState(for meeting: ArmedMeeting, context: ProviderPollContext) async -> ProviderState {
        let workspace = NSWorkspace.shared
        let applications = workspace.runningApplications

        let matchingApp = applications.first { app in
            app.bundleIdentifier == context.settings.gatherBundleIdentifier
            || app.localizedName == context.settings.gatherProcessName
        }

        guard let matchingApp else {
            return .inactive
        }

        if matchingApp.isActive {
            return .joined
        }

        if let lastSystemAudioActivity = context.lastSystemAudioActivity,
           context.now.timeIntervalSince(lastSystemAudioActivity) < 3 * 60 {
            return .joined
        }

        return .inactive
    }
}
