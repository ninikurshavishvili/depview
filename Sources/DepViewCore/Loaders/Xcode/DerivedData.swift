import CryptoKit
import Foundation

/// Finds the DerivedData folder Xcode uses for a project, and reads which packages
/// Xcode downloaded into it.
enum DerivedData {
    /// A package Xcode resolved, and the folder that holds its files.
    struct Package: Equatable {
        let identity: String
        let name: String
        let location: String?
        let folder: URL
    }

    /// Where Xcode keeps DerivedData: the location set in Xcode's settings, or the default.
    static func root(relativeTo project: URL) -> URL {
        if let custom = UserDefaults(suiteName: "com.apple.dt.Xcode")?.string(forKey: "IDECustomDerivedDataLocation"),
           !custom.isEmpty {
            let path = NSString(string: custom).expandingTildeInPath
            // A relative location is relative to the folder that holds the project.
            return path.hasPrefix("/") ? URL(fileURLWithPath: path)
                : project.deletingLastPathComponent().appendingPathComponent(path)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")
    }

    /// The folder in `root` whose info.plist points at `project`, the newest if there are several.
    /// Folder names are "<Name>-<hash>", but moved or renamed projects leave stale folders behind,
    /// so the WorkspacePath inside decides. xcodebuild -resolvePackageDependencies writes no
    /// info.plist, so without one the folder named with the project path's hash is used.
    static func folder(for project: URL, in root: URL) -> URL? {
        let target = project.resolvingSymlinksInPath().standardizedFileURL.path
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        let newest = folders
            .compactMap { folder -> (folder: URL, lastUsed: Date)? in
                guard let data = try? Data(contentsOf: folder.appendingPathComponent("info.plist")),
                      let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      let path = info["WorkspacePath"] as? String,
                      URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path == target else {
                    return nil
                }
                return (folder, info["LastAccessedDate"] as? Date ?? .distantPast)
            }
            .max { $0.lastUsed < $1.lastUsed }?
            .folder
        if let newest { return newest }
        let suffix = "-" + folderHash(for: project.standardizedFileURL.path)
        return folders.first { $0.lastPathComponent.hasSuffix(suffix) }
    }

    /// The hash Xcode puts in a DerivedData folder's name: the MD5 of the project's path,
    /// each half written in base 26 with the letters a to z.
    static func folderHash(for path: String) -> String {
        let digest = Array(Insecure.MD5.hash(data: Data(path.utf8)))
        func letters(_ bytes: ArraySlice<UInt8>) -> String {
            var value = bytes.reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
            var result: [Character] = []
            for _ in 0..<14 {
                result.append(Character(UnicodeScalar(UInt8(ascii: "a") + UInt8(value % 26))))
                value /= 26
            }
            return String(result.reversed())
        }
        return letters(digest[0..<8]) + letters(digest[8..<16])
    }

    /// Every package listed in SourcePackages/workspace-state.json, or nil if there's no such file.
    static func packages(inSourcePackages sourcePackages: URL) -> [Package]? {
        guard let data = try? Data(contentsOf: sourcePackages.appendingPathComponent("workspace-state.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let object = json["object"] as? [String: Any],
              let dependencies = object["dependencies"] as? [[String: Any]] else {
            return nil
        }
        return dependencies.compactMap { dependency in
            guard let reference = dependency["packageRef"] as? [String: Any],
                  let identity = reference["identity"] as? String else { return nil }
            let location = reference["location"] as? String
            let state = dependency["state"] as? [String: Any]
            let subpath = dependency["subpath"] as? String ?? identity
            let folder: URL
            switch state?["name"] as? String {
            case "fileSystem":
                guard let path = state?["path"] as? String ?? location else { return nil }
                folder = URL(fileURLWithPath: path)
            case "registryDownload":
                folder = sourcePackages.appendingPathComponent("registry/downloads").appendingPathComponent(subpath)
            default:
                folder = sourcePackages.appendingPathComponent("checkouts").appendingPathComponent(subpath)
            }
            return Package(identity: identity, name: reference["name"] as? String ?? identity,
                           location: location, folder: folder)
        }
    }
}
