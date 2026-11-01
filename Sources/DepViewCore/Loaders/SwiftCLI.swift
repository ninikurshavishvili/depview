import Foundation

/// Runs `swift` subcommands.
enum SwiftCLI {
    /// Runs `swift <arguments>` in a folder and returns what it printed to stdout.
    static func run(_ arguments: [String], in folder: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift"] + arguments
        process.currentDirectoryURL = folder

        let output = Pipe()
        process.standardOutput = output

        // stderr goes to a temporary file, not a second pipe: reading two pipes one
        // after the other deadlocks when the unread one fills up.
        let errorLog = FileManager.default.temporaryDirectory
            .appendingPathComponent("depview-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: errorLog.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: errorLog) }
        let errorHandle = try FileHandle(forWritingTo: errorLog)
        defer { try? errorHandle.close() }
        process.standardError = errorHandle

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        switch process.terminationStatus {
        case 0:
            return data
        case 127:  // env couldn't find swift
            throw DepViewError.swiftNotFound
        default:
            let errors = (try? String(contentsOf: errorLog, encoding: .utf8)) ?? ""
            throw DepViewError.swiftCommandFailed(output: errors.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
