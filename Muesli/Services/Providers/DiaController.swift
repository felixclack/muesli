import Foundation
import OSLog

struct DiaTab: Decodable, Hashable, Sendable {
    let windowIndex: Int
    let tabIndex: Int
    let tabID: String
    let loading: Bool
    let focused: Bool
    let url: String
    let title: String
}

actor DiaController {
    enum DiaError: Error {
        case osascriptFailed(String)
        case invalidResponse
        case tabNotFound
    }

    func automationPermissionGranted() async -> Bool {
        do {
            _ = try await runAppleScript("""
            tell application "Dia"
                return count of windows
            end tell
            """)
            return true
        } catch {
            Logger.providers.error("Dia permission probe failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func tabs() async throws -> [DiaTab] {
        let output = try await runAppleScript("""
        set outputLines to ""
        tell application "Dia"
            set windowNumber to 1
            repeat with theWindow in (every window)
                set tabNumber to 1
                repeat with theTab in (tabs of theWindow)
                    set tID to id of theTab as text
                    set loadingValue to loading of theTab as text
                    set focusedValue to isFocused of theTab as text
                    set tURL to URL of theTab as text
                    set tTitle to title of theTab as text
                    set outputLines to outputLines & windowNumber & tab & tabNumber & tab & tID & tab & loadingValue & tab & focusedValue & tab & tURL & tab & tTitle & linefeed
                    set tabNumber to tabNumber + 1
                end repeat
                set windowNumber to windowNumber + 1
            end repeat
        end tell
        return outputLines
        """)

        return output
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard parts.count >= 7,
                      let windowIndex = Int(parts[0]),
                      let tabIndex = Int(parts[1]) else {
                    return nil
                }

                return DiaTab(
                    windowIndex: windowIndex,
                    tabIndex: tabIndex,
                    tabID: String(parts[2]),
                    loading: String(parts[3]).lowercased() == "true",
                    focused: String(parts[4]).lowercased() == "true",
                    url: String(parts[5]),
                    title: String(parts[6])
                )
            }
    }

    func executeJavaScript(tabID: String, source: String) async throws -> String {
        let escapedTabID = tabID.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedSource = source
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return try await runAppleScript("""
        tell application "Dia"
            repeat with theWindow in windows
                repeat with theTab in tabs of theWindow
                    if (id of theTab as text) is "\(escapedTabID)" then
                        return execute theTab javascript "\(escapedSource)"
                    end if
                end repeat
            end repeat
        end tell
        error "tab not found"
        """)
    }

    private func runAppleScript(_ source: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { process in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let out = String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                let err = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

                if process.terminationStatus == 0 {
                    continuation.resume(returning: out)
                } else {
                    continuation.resume(throwing: DiaError.osascriptFailed(err.isEmpty ? out : err))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
