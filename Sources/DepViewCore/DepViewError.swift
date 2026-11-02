import Foundation

/// Every failure depview reports, each with a message and a hint for fixing it.
public enum DepViewError: LocalizedError, Equatable, Sendable {
    case folderNotFound(path: String)
    case noPackageManifest(path: String)
    case swiftNotFound
    case swiftCommandFailed(output: String)
    case unreadableOutput
    case packageNotFound(name: String, suggestions: [String])
    case cannotWriteFile(path: String)
    case noProject(path: String)
    case severalProjects(path: String, names: [String])
    case unreadableProject(path: String)
    case derivedDataNotFound(path: String)

    public var message: String {
        switch self {
        case .folderNotFound(let path): "No folder at \(path)."
        case .noPackageManifest(let path): "No Package.swift in \(path)."
        case .swiftNotFound: "The swift command wasn't found."
        case .swiftCommandFailed(let output): "SwiftPM couldn't read the package:\n\(output)"
        case .unreadableOutput: "SwiftPM printed a dependency list depview can't read."
        case .packageNotFound(let name, _): "No package named \(name) in the dependency graph."
        case .cannotWriteFile(let path): "Couldn't write \(path)."
        case .noProject(let path): "No Package.swift or Xcode project in \(path)."
        case .severalProjects(let path, let names): "\(path) has several Xcode projects: \(names.joined(separator: ", "))."
        case .unreadableProject(let path): "Couldn't read \(path)."
        case .derivedDataNotFound(let path): "No resolved packages in \(path)."
        }
    }

    /// How to fix it. Not optional, so a new case can't be added without one.
    public var hint: String {
        switch self {
        case .folderNotFound: "Check the path, or run depview from inside the project folder."
        case .noPackageManifest: "Pass the folder that contains Package.swift."
        case .swiftNotFound: "Install Xcode, then run: xcode-select --install"
        case .swiftCommandFailed: "Fix the error above. swift package resolve in that folder shows SwiftPM's full output."
        case .unreadableOutput: "Please open an issue with your Swift version (swift --version)."
        case .packageNotFound(_, let suggestions) where suggestions.isEmpty:
            "Run depview tree to see every package's name."
        case .packageNotFound(_, let suggestions): "Did you mean \(suggestions.joined(separator: ", "))?"
        case .cannotWriteFile: "Check that the folder exists and that you can write to it."
        case .noProject: "Pass a folder with Package.swift, an .xcodeproj or an .xcworkspace."
        case .severalProjects(let path, let names):
            "Pass the one you want, e.g. \(URL(fileURLWithPath: path).appendingPathComponent(names[0]).path)"
        case .unreadableProject: "Check that Xcode can open it, then try again."
        case .derivedDataNotFound:
            "Pass the folder you gave xcodebuild -derivedDataPath, after its packages are resolved."
        }
    }

    /// 1 when something the user gave needs fixing, like a path or a package name;
    /// 2 when a tool depview runs failed. Argument Parser uses 64 for a wrong command line.
    public var exitCode: Int32 {
        switch self {
        case .folderNotFound, .noPackageManifest, .packageNotFound, .cannotWriteFile, .noProject,
             .severalProjects, .unreadableProject, .derivedDataNotFound:
            1
        case .swiftNotFound, .swiftCommandFailed, .unreadableOutput:
            2
        }
    }

    public var recoverySuggestion: String? { hint }

    public var errorDescription: String? { "\(message)\nHint: \(hint)" }
}
