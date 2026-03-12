import XCTest
@testable import Muesli

final class SessionRepositoryTests: XCTestCase {
    func testCreatesStorageFolderWithSluggedTitle() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let repository = SessionRepository(fileManager: .default, baseURL: root)
        let folderURL = try await repository.createStorageFolder(for: "Design Review / Sync", startDate: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertTrue(FileManager.default.fileExists(atPath: folderURL.path))
        XCTAssertTrue(folderURL.lastPathComponent.contains("design-review-sync"))
    }
}
