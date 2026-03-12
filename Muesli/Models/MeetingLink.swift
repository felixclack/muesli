import Foundation

struct MeetingLink: Codable, Hashable, Sendable {
    let originalURL: URL
    let canonicalURL: URL
    let provider: MeetingProviderKind
}
