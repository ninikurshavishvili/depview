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
            throw DepViewError.swiftCommandFailed(output: errorLines(in: errors))
        }
    }

    /// The error lines in what SwiftPM printed, without the compiler command it adds to a
    /// broken manifest's error, the code excerpts, or warnings. All of it if there are none.
    static func errorLines(in output: String) -> String {
        let lines = output.split(separator: "\n").map(String.init).filter { line in
            // Excerpt lines start with spaces or "6 |"; file errors with a path.
            guard let first = line.first, !first.isWhitespace, !first.isNumber else { return false }
            return line.hasPrefix("error:") || line.contains(": error:")
        }
        guard !lines.isEmpty else { return output.trimmingCharacters(in: .whitespacesAndNewlines) }
        return lines
            .map { $0.replacing(#/ \(compiled with: \[.*\]\)/#, with: "") }
            .joined(separator: "\n")
    }
}
