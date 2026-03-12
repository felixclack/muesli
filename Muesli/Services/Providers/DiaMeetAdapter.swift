import Foundation
import OSLog

actor DiaMeetAdapter: MeetingProviderAdapter {
    nonisolated let provider: MeetingProviderKind = .googleMeet

    private let controller: DiaController
    private var focusedPollCounts: [String: Int] = [:]

    init(controller: DiaController) {
        self.controller = controller
    }

    nonisolated func supports(_ link: MeetingLink) -> Bool {
        link.provider == .googleMeet
    }

    func pollState(for meeting: ArmedMeeting, context: ProviderPollContext) async -> ProviderState {
        do {
            let tabs = try await controller.tabs()
            let matchingTabs = tabs.filter { tab in
                guard let url = URL(string: tab.url),
                      let canonical = MeetingURLExtractor.canonicalURL(for: url) else {
                    return false
                }

                return canonical == meeting.candidate.link.canonicalURL
            }

            guard !matchingTabs.isEmpty else {
                focusedPollCounts[meeting.canonicalMeetingKey] = 0
                return .inactive
            }

            // Dia's AppleScript JavaScript bridge is unstable on this machine and can crash the browser,
            // so V1 falls back to a safer tab-presence heuristic instead of probing the page DOM.
            let hasReadyTab = matchingTabs.contains { !$0.loading }
            let hasFocusedReadyTab = matchingTabs.contains { $0.focused && !$0.loading }

            if !hasReadyTab {
                focusedPollCounts[meeting.canonicalMeetingKey] = 0
                return .indeterminate
            }

            if context.lastSystemAudioActivity != nil {
                return .joined
            }

            if hasFocusedReadyTab {
                let pollCount = focusedPollCounts[meeting.canonicalMeetingKey, default: 0] + 1
                focusedPollCounts[meeting.canonicalMeetingKey] = pollCount
                if pollCount >= 2 {
                    return .joined
                }
            } else {
                focusedPollCounts[meeting.canonicalMeetingKey] = 0
            }

            return .waitingRoom
        } catch {
            Logger.providers.error("Dia poll failed: \(error.localizedDescription, privacy: .public)")
            return .indeterminate
        }
    }
}
