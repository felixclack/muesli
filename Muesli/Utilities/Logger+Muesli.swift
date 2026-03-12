import OSLog

extension Logger {
    static let app = Logger(subsystem: "com.felixclack.Muesli", category: "app")
    static let permissions = Logger(subsystem: "com.felixclack.Muesli", category: "permissions")
    static let calendar = Logger(subsystem: "com.felixclack.Muesli", category: "calendar")
    static let providers = Logger(subsystem: "com.felixclack.Muesli", category: "providers")
    static let recorder = Logger(subsystem: "com.felixclack.Muesli", category: "recorder")
    static let transcription = Logger(subsystem: "com.felixclack.Muesli", category: "transcription")
    static let storage = Logger(subsystem: "com.felixclack.Muesli", category: "storage")
}
