import Foundation

/// A package that an Xcode project lists in its Package Dependencies.
struct PackageReference: Equatable {
    enum Source: Equatable {
        case remote(url: String)
        case local(folder: URL)
    }

    let identity: String
    let name: String
    let source: Source
    /// A package folder in the navigator or the workspace, not a package reference.
    /// The app uses it only if one of its targets links one of the package's products.
    var isFolderEntry = false

    var isRemote: Bool {
        if case .remote = source { return true }
        return false
    }
}

extension PackageReference {
    /// The package in `folder`, named after the folder the way SwiftPM names it.
    init(localFolder folder: URL, isFolderEntry: Bool = false) {
        let folder = folder.standardizedFileURL
        self.init(identity: packageIdentity(for: folder.path), name: folder.lastPathComponent,
                  source: .local(folder: folder), isFolderEntry: isFolderEntry)
    }
}

/// Reads the parts of .xcodeproj and .xcworkspace files that list packages and projects.
enum XcodeProjectFile {
    /// The package references in project.pbxproj, in the order Xcode lists them, then the
    /// package folders in the project navigator.
    static func packageReferences(in project: URL) throws -> [PackageReference] {
        let (objects, rootID) = try Self.objects(in: project)
        // Local package paths are relative to the folder that holds the .xcodeproj.
        let base = project.deletingLastPathComponent()
        let ids = objects[rootID]?["packageReferences"] as? [String] ?? []
        var references: [PackageReference] = ids.compactMap { id in
            guard let object = objects[id] else { return nil }
            switch object["isa"] as? String {
            case "XCRemoteSwiftPackageReference":
                guard let url = object["repositoryURL"] as? String else { return nil }
                return PackageReference(identity: packageIdentity(for: url), name: packageName(for: url),
                                        source: .remote(url: url))
            case "XCLocalSwiftPackageReference":
                guard let path = object["relativePath"] as? String else { return nil }
                return PackageReference(localFolder: base.appendingPathComponent(path))
            default:
                return nil
            }
        }

        // Older projects add a local package by dragging its folder into the navigator,
        // which makes a plain folder entry instead of a package reference. Each entry's
        // path is relative to its group's folder.
        func packageFolders(in id: String, groupFolder: URL) -> [URL] {
            guard let object = objects[id] else { return [] }
            let path = object["path"] as? String
            let folder: URL
            switch object["sourceTree"] as? String {
            case "<group>":
                folder = path.map { groupFolder.appendingPathComponent($0) } ?? groupFolder
            case "SOURCE_ROOT":
                folder = path.map { base.appendingPathComponent($0) } ?? base
            case "<absolute>":
                guard let path else { return [] }
                folder = URL(fileURLWithPath: path)
            default:
                // Built products and SDK files are never packages.
                return []
            }
            if let children = object["children"] as? [String] {
                return children.flatMap { packageFolders(in: $0, groupFolder: folder) }
            }
            let type = object["lastKnownFileType"] as? String
            return (type == "wrapper" || type == "folder") && hasManifest(folder) ? [folder] : []
        }
        if let mainGroup = objects[rootID]?["mainGroup"] as? String {
            for folder in packageFolders(in: mainGroup, groupFolder: base) {
                let reference = PackageReference(localFolder: folder, isFolderEntry: true)
                if !references.contains(where: { $0.identity == reference.identity }) {
                    references.append(reference)
                }
            }
        }
        return references
    }

    /// The products targets link from package folders. Products from package references
    /// name their package; these don't, e.g. { productName = Timeline; }.
    static func linkedProducts(in project: URL) throws -> Set<String> {
        let (objects, _) = try Self.objects(in: project)
        var products: Set<String> = []
        for object in objects.values
        where object["isa"] as? String == "XCSwiftPackageProductDependency" && object["package"] == nil {
            if let name = object["productName"] as? String {
                // Build tool plugins are listed as "plugin:<name>".
                products.insert(name.hasPrefix("plugin:") ? String(name.dropFirst(7)) : name)
            }
        }
        return products
    }

    /// project.pbxproj's objects by id, and the id of the project object.
    /// project.pbxproj is an old-style property list, so Foundation reads it directly.
    private static func objects(in project: URL) throws -> (objects: [String: [String: Any]], rootID: String) {
        let file = project.appendingPathComponent("project.pbxproj")
        guard let data = try? Data(contentsOf: file),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let objects = plist["objects"] as? [String: [String: Any]],
              let rootID = plist["rootObject"] as? String else {
            throw DepViewError.unreadableProject(path: project.path)
        }
        return (objects, rootID)
    }

    /// The .xcodeproj files listed in a workspace's contents.xcworkspacedata.
    static func projects(inWorkspace workspace: URL) throws -> [URL] {
        try items(inWorkspace: workspace).filter { $0.pathExtension == "xcodeproj" }
    }

    /// The package folders listed in a workspace, e.g. a Modules folder next to the app project.
    static func packageFolders(inWorkspace workspace: URL) throws -> [URL] {
        try items(inWorkspace: workspace).filter(hasManifest)
    }

    /// Every file and folder listed in a workspace's contents.xcworkspacedata.
    private static func items(inWorkspace workspace: URL) throws -> [URL] {
        let file = workspace.appendingPathComponent("contents.xcworkspacedata")
        guard let xml = try? String(contentsOf: file, encoding: .utf8) else {
            throw DepViewError.unreadableProject(path: workspace.path)
        }
        let base = workspace.deletingLastPathComponent()
        // Entries look like <FileRef location = "group:App.xcodeproj">.
        let entry = #/location\s*=\s*"(group|container|absolute):([^"]+)"/#
        return xml.matches(of: entry).map { match in
            let path = String(match.output.2)
            return match.output.1 == "absolute" ? URL(fileURLWithPath: path) : base.appendingPathComponent(path)
        }
    }

    private static func hasManifest(_ folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent("Package.swift").path)
    }
}

/// SwiftPM's identity for a package URL or path: its last path component, lowercased,
/// without ".git". "https://github.com/apple/swift-nio.git" becomes "swift-nio".
func packageIdentity(for location: String) -> String {
    packageName(for: location).lowercased()
}

/// The last path component of a package URL or path, without ".git", e.g. "RouteReplay".
func packageName(for location: String) -> String {
    var name = location
    while name.hasSuffix("/") { name.removeLast() }
    if let separator = name.lastIndex(where: { $0 == "/" || $0 == ":" }) {
        name = String(name[name.index(after: separator)...])
    }
    if name.lowercased().hasSuffix(".git") { name.removeLast(4) }
    return name
}
