import Foundation

enum MeetingURLExtractor {
    static func extract(from eventURL: URL?, location: String?, notes: String?) -> MeetingLink? {
        if let eventURL, let direct = meetingLink(from: eventURL) {
            return direct
        }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let texts = [location, notes].compactMap { $0 }

        for text in texts {
            var foundLink: MeetingLink?
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            detector?.enumerateMatches(in: text, options: [], range: range) { result, _, stop in
                guard let url = result?.url, foundLink == nil else { return }
                foundLink = meetingLink(from: url)
                if foundLink != nil {
                    stop.pointee = true
                }
            }
            if let foundLink { return foundLink }
        }

        return nil
    }

    static func canonicalURL(for url: URL) -> URL? {
        meetingLink(from: url)?.canonicalURL
    }
    private static func meetingLink(from url: URL) -> MeetingLink? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased()
        else {
            return nil
        }

        if host == "meet.google.com" {
            components.query = nil
            components.fragment = nil
            components.scheme = "https"
            guard let canonicalURL = components.url else { return nil }
            return MeetingLink(originalURL: url, canonicalURL: canonicalURL, provider: .googleMeet)
        }

        if host == "gather.town" || host == "app.gather.town" || host.hasSuffix(".gather.town") {
            components.query = nil
            components.fragment = nil
            components.scheme = "https"
            guard let canonicalURL = components.url else { return nil }
            return MeetingLink(originalURL: url, canonicalURL: canonicalURL, provider: .gather)
        }

        return nil
    }
}
