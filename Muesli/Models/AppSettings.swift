import Foundation

struct AppSettings: Codable, Hashable, Sendable {
    var launchAtLoginEnabled: Bool
    var gatherBundleIdentifier: String
    var gatherProcessName: String
    var modelName: String
    var startLeadTime: TimeInterval
    var endGraceTime: TimeInterval
    var pollingInterval: TimeInterval

    static let `default` = AppSettings(
        launchAtLoginEnabled: false,
        gatherBundleIdentifier: "town.gather.desktop",
        gatherProcessName: "Gather",
        modelName: "ggml-small.en.bin",
        startLeadTime: 15 * 60,
        endGraceTime: 2 * 60 * 60,
        pollingInterval: 5
    )
}
