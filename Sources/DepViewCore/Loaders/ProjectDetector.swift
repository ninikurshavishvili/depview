import Foundation

/// What a path points at, and so which loader reads it.
public enum Project: Equatable, Sendable {
    /// A folder with Package.swift.
    case swiftPackage(URL)
    /// An .xcodeproj or .xcworkspace.
    case xcode(URL)
}

public enum ProjectDetector {
    /// Package.swift wins over an Xcode project in the same folder, and a workspace
    /// wins over a project, because the workspace holds Package.resolved (e.g. with CocoaPods).
    public static func detect(_ url: URL) throws -> Project {
        if url.lastPathComponent == "Package.swift" {
            return try detect(url.deletingLastPathComponent())
        }
        let fileManager = FileManager.default
        var isFolder: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isFolder), isFolder.boolValue else {
            throw DepViewError.folderNotFound(path: url.path)
        }
        if ["xcodeproj", "xcworkspace"].contains(url.pathExtension) {
            return .xcode(url)
        }
        if fileManager.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            return .swiftPackage(url)
        }

        let contents = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil,
                                                             options: .skipsHiddenFiles)) ?? []
        for pathExtension in ["xcworkspace", "xcodeproj"] {
            let matches = contents.filter { $0.pathExtension == pathExtension }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            if matches.count == 1 {
                return .xcode(matches[0])
            }
            if matches.count > 1 {
                throw DepViewError.severalProjects(path: url.path, names: matches.map(\.lastPathComponent))
            }
        }
        throw DepViewError.noProject(path: url.path)
    }
}
