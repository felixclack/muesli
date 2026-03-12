import EventKit
import Foundation
import OSLog

struct CalendarSnapshot: Sendable {
    let candidates: [MeetingCandidate]
    let upcomingTodayMeetings: [UpcomingMeetingSummary]

    static let empty = CalendarSnapshot(candidates: [], upcomingTodayMeetings: [])
}

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
        fetchSnapshot(referenceDate: referenceDate).candidates
    }

    func fetchSnapshot(referenceDate: Date = .now) -> CalendarSnapshot {
        let events = events(around: referenceDate)

        let candidates = events.compactMap(candidate(from:))
        let allUpcomingMeetings = events.compactMap(upcomingMeetingSummary(from:))

        return CalendarSnapshot(
            candidates: candidates,
            upcomingTodayMeetings: UpcomingMeetingSummary.nextThreeToday(from: allUpcomingMeetings, now: referenceDate)
        )
    }

    private func events(around referenceDate: Date) -> [EKEvent] {
        let start = referenceDate.addingTimeInterval(-2 * 60 * 60)
        let end = referenceDate.addingTimeInterval(24 * 60 * 60)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)

        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    private func candidate(from event: EKEvent) -> MeetingCandidate? {
        guard let link = MeetingURLExtractor.extract(from: event.url, location: event.location, notes: event.notes) else {
            return nil
        }

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

    private func upcomingMeetingSummary(from event: EKEvent) -> UpcomingMeetingSummary? {
        let trimmedTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines)

        return UpcomingMeetingSummary(
            eventIdentifier: event.eventIdentifier,
            title: trimmedTitle.isEmpty ? "Untitled Meeting" : trimmedTitle,
            startDate: event.startDate,
            participantSummary: participantSummary(for: event),
            platformName: MeetingURLExtractor.platformDisplayName(
                for: event.url,
                location: event.location,
                notes: event.notes
            ) ?? (location?.isEmpty == false ? "In Person" : "No link")
        )
    }

    private func participantSummary(for event: EKEvent) -> String? {
        var seen = Set<String>()
        var names: [String] = []

        for attendee in event.attendees ?? [] {
            guard !attendee.isCurrentUser else { continue }
            guard attendee.participantRole != .nonParticipant else { continue }
            guard let name = participantDisplayName(for: attendee) else { continue }

            let normalized = name.lowercased()
            guard seen.insert(normalized).inserted else { continue }
            names.append(name)
        }

        if names.isEmpty,
           let organizer = event.organizer,
           !organizer.isCurrentUser,
           let organizerName = participantDisplayName(for: organizer)
        {
            names.append(organizerName)
        }

        switch names.count {
        case 0:
            return nil
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) and \(names[1])"
        default:
            return "\(names[0]) +\(names.count - 1)"
        }
    }

    private func participantDisplayName(for participant: EKParticipant) -> String? {
        let rawName = participant.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawName, !rawName.isEmpty {
            return rawName
        }

        let normalized = participant.url.absoluteString
            .replacingOccurrences(of: "mailto:", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        return normalized.isEmpty ? nil : normalized
    }
}
