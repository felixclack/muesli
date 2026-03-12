import Foundation

struct ProviderPollContext: Sendable {
    let settings: AppSettings
    let now: Date
    let lastSystemAudioActivity: Date?
}

protocol MeetingProviderAdapter: Sendable {
    var provider: MeetingProviderKind { get }
    func supports(_ link: MeetingLink) -> Bool
    func pollState(for meeting: ArmedMeeting, context: ProviderPollContext) async -> ProviderState
}
