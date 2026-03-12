import Foundation
import OSLog

actor SessionRepository {
    private let fileManager: FileManager
    private let baseURL: URL

    init(fileManager: FileManager = .default, baseURL: URL? = nil) {
        self.fileManager = fileManager
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseURL = applicationSupport.appendingPathComponent("Muesli/Meetings", isDirectory: true)
        }
    }

    func ensureBaseDirectory() throws {
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func createStorageFolder(for title: String, startDate: Date) throws -> URL {
        try ensureBaseDirectory()
        let relativeDayPath = DateFormatters.dayFolder.string(from: startDate)
        let dayURL = baseURL.appendingPathComponent(relativeDayPath, isDirectory: true)
        try fileManager.createDirectory(at: dayURL, withIntermediateDirectories: true)

        let folderName = "\(DateFormatters.sessionFolder.string(from: startDate))-\(title.slugified)"
        let folderURL = dayURL.appendingPathComponent(folderName, isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }

    func metadataURL(for session: MeetingSession) -> URL {
        URL(fileURLWithPath: session.storageFolderPath).appendingPathComponent("metadata.json")
    }

    func persist(_ session: MeetingSession) throws {
        let data = try JSONEncoder.pretty.encode(session)
        try data.write(to: metadataURL(for: session), options: .atomic)
    }

    func loadSessions() throws -> [MeetingSession] {
        guard fileManager.fileExists(atPath: baseURL.path) else { return [] }

        let enumerator = fileManager.enumerator(at: baseURL, includingPropertiesForKeys: nil)
        var sessions: [MeetingSession] = []

        while let url = enumerator?.nextObject() as? URL {
            guard url.lastPathComponent == "metadata.json" else { continue }
            do {
                let data = try Data(contentsOf: url)
                let session = try JSONDecoder.iso8601.decode(MeetingSession.self, from: data)
                sessions.append(session)
            } catch {
                Logger.storage.error("Failed to decode session metadata at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return sessions.sorted {
            ($0.startedAt ?? $0.scheduledStart) > ($1.startedAt ?? $1.scheduledStart)
        }
    }
}
