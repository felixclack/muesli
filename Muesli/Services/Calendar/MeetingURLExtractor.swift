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

    static func platformDisplayName(for eventURL: URL?, location: String?, notes: String?) -> String? {
        if let link = extract(from: eventURL, location: location, notes: notes) {
            return link.provider.displayName
        }

        guard let url = firstDetectedURL(from: eventURL, location: location, notes: notes),
              let host = url.host?.lowercased()
        else {
            return nil
        }

        if host == "zoom.us" || host.hasSuffix(".zoom.us") {
            return "Zoom"
        }

        if host == "teams.microsoft.com" || host == "teams.live.com" || host.hasSuffix(".teams.microsoft.com") {
            return "Microsoft Teams"
        }

        if host == "webex.com" || host.hasSuffix(".webex.com") {
            return "Webex"
        }

        if host == "whereby.com" || host.hasSuffix(".whereby.com") {
            return "Whereby"
        }

        if host == "meet.google.com" {
            return "Google Meet"
        }

        if host == "gather.town" || host == "app.gather.town" || host.hasSuffix(".gather.town") {
            return "Gather"
        }

        return hostDisplayName(for: host)
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

    private static func firstDetectedURL(from eventURL: URL?, location: String?, notes: String?) -> URL? {
        if let eventURL {
            return eventURL
        }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let texts = [location, notes].compactMap { $0 }

        for text in texts {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let result = detector?.firstMatch(in: text, options: [], range: range)?.url {
                return result
            }
        }

        return nil
    }

    private static func hostDisplayName(for host: String) -> String {
        let labels = host
            .split(separator: ".")
            .filter { $0 != "www" && $0 != "app" }
            .map(String.init)

        guard let primaryLabel = labels.dropLast().last ?? labels.first else {
            return host
        }

        return primaryLabel
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}
