import EventKit
import Foundation
import OSLog

actor CalendarMeetingSource {
    private let eventStore = EKEventStore()

    func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestFullAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error {
                    Logger.calendar.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    func fetchCandidates(referenceDate: Date = .now) -> [MeetingCandidate] {
        let start = referenceDate.addingTimeInterval(-2 * 60 * 60)
        let end = referenceDate.addingTimeInterval(24 * 60 * 60)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        return events.compactMap { event in
            guard !event.isAllDay else { return nil }
            guard let link = MeetingURLExtractor.extract(from: event.url, location: event.location, notes: event.notes) else { return nil }

            return MeetingCandidate(
                eventIdentifier: event.eventIdentifier,
                calendarTitle: event.calendar.title,
                title: event.title.isEmpty ? link.provider.displayName : event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                notes: event.notes,
                link: link
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }
}
