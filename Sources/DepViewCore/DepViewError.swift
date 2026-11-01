import Foundation

/// Every failure depview reports, each with a message and a hint for fixing it.
public enum DepViewError: LocalizedError, Equatable {
    case folderNotFound(path: String)
    case noPackageManifest(path: String)
    case swiftNotFound
    case swiftCommandFailed(output: String)
    case unreadableOutput

    public var message: String {
        switch self {
        case .folderNotFound(let path): "No folder at \(path)."
        case .noPackageManifest(let path): "No Package.swift in \(path)."
        case .swiftNotFound: "The swift command wasn't found."
        case .swiftCommandFailed(let output): "SwiftPM couldn't read the package:\n\(output)"
        case .unreadableOutput: "SwiftPM printed a dependency list depview can't read."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .folderNotFound: "Check the path, or run depview from inside the project folder."
        case .noPackageManifest: "Pass the folder that contains Package.swift."
        case .swiftNotFound: "Install Xcode, then run: xcode-select --install"
        case .swiftCommandFailed: "Run swift package resolve in that folder and fix the error it shows."
        case .unreadableOutput: "Please open an issue with your Swift version (swift --version)."
        }
    }

    // Argument Parser prints only errorDescription, so the hint goes in it too.
    public var errorDescription: String? {
        recoverySuggestion.map { "\(message)\nHint: \($0)" } ?? message
    }
}
