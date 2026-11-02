import Foundation

/// Loads the packages of an Xcode app project. The packages it uses directly come from
/// project.pbxproj, versions from Package.resolved, and the links between packages from
/// the manifests of the copies Xcode downloaded into DerivedData.
public struct XcodeLoader: GraphLoader {
    /// The project's own DerivedData folder, the one that holds SourcePackages (what
    /// `xcodebuild -derivedDataPath` takes). nil finds it the way Xcode does.
    public var derivedData: URL?
    /// Where to look for DerivedData folders instead of Xcode's location. Tests set it.
    var derivedDataRoot: URL?
    var manifestReader: any ManifestReader = DumpPackageReader()

    public init(derivedData: URL? = nil) {
        self.derivedData = derivedData
    }

    /// `project` is an .xcodeproj or .xcworkspace.
    public func load(from project: URL) throws -> DependencyGraph {
        try loadWithWarnings(from: project).graph
    }

    /// Like `load(from:)`, plus a warning for anything left out of the graph.
    public func loadWithWarnings(from project: URL) throws -> (graph: DependencyGraph, warnings: [String]) {
        var warnings: [String] = []
        let name = project.deletingPathExtension().lastPathComponent

        let projectFiles: [URL]
        var packageFolders: [URL] = []
        let resolvedFile: URL
        if project.pathExtension == "xcworkspace" {
            let members = try XcodeProjectFile.projects(inWorkspace: project)
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            if members.contains(where: { $0.lastPathComponent == "Pods.xcodeproj" }) {
                warnings.append("This workspace also uses CocoaPods. Pods aren't shown yet; "
                                + "support for them is planned for depview 1.1.")
            }
            projectFiles = members.filter { $0.lastPathComponent != "Pods.xcodeproj" }
            packageFolders = try XcodeProjectFile.packageFolders(inWorkspace: project)
            resolvedFile = project.appendingPathComponent("xcshareddata/swiftpm/Package.resolved")
        } else {
            projectFiles = [project]
            resolvedFile = project.appendingPathComponent("project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
        }

        var direct: [PackageReference] = []
        let references = try projectFiles.flatMap { try XcodeProjectFile.packageReferences(in: $0) }
            + packageFolders.map(PackageReference.init(localFolder:))
        for reference in references where !direct.contains(where: { $0.identity == reference.identity }) {
            direct.append(reference)
        }

        var pins: [String: PackagePin] = [:]
        if FileManager.default.fileExists(atPath: resolvedFile.path) {
            guard let data = try? Data(contentsOf: resolvedFile), let list = PackageResolved.pins(from: data) else {
                throw DepViewError.unreadableProject(path: resolvedFile.path)
            }
            for pin in list { pins[pin.identity] = pin }
        }

        let downloaded = try downloadedPackages(for: project)
        if downloaded == nil && direct.contains(where: \.isRemote) {
            warnings.append("Xcode hasn't downloaded \(name)'s packages yet, so only its direct dependencies "
                            + "are shown. Open it in Xcode and let the packages resolve, or pass --derived-data "
                            + "if you used xcodebuild -derivedDataPath.")
        }

        // Every package Xcode resolved, then the direct ones it hasn't.
        var found: [String: Found] = [:]
        var order: [String] = []
        func add(_ identity: String, _ package: Found) {
            guard found[identity] == nil else { return }
            found[identity] = package
            order.append(identity)
        }
        for package in downloaded ?? [] {
            add(package.identity, Found(name: package.name, url: package.location, folder: package.folder))
        }
        for reference in direct {
            switch reference.source {
            case .remote(let url): add(reference.identity, Found(name: reference.name, url: url, folder: nil))
            case .local(let folder): add(reference.identity, Found(name: reference.name, url: folder.path, folder: folder))
            }
        }

        let readable = order.compactMap { id in found[id]?.folder.map { (id: id, folder: $0) } }
            .filter { FileManager.default.fileExists(atPath: $0.folder.path) }
        let manifests = readManifests(readable)
        var loaded: [String: Manifest] = [:]
        for (id, result) in manifests {
            if case .success(let manifest) = result { loaded[id] = manifest }
        }

        // The traits each package has on: its defaults, which the app asks for, plus any
        // that other manifests ask for. Some dependencies only count when a trait is on.
        var requested: [String: Set<String>] = [:]
        for reference in direct {
            requested[reference.identity, default: []].insert("default")
        }
        for manifest in loaded.values {
            for dependency in manifest.dependencies {
                requested[dependency.identity, default: []].formUnion(dependency.traits)
            }
        }

        var nodes: [String: DependencyNode] = [:]
        for id in order {
            guard let package = found[id] else { continue }
            var children: [String] = []
            switch manifests[id] {
            case .success(let manifest):
                let traits = manifest.expand(requested[id] ?? ["default"])
                // Keep just the packages Xcode resolved; that also drops ones Xcode never needed.
                children = manifest.usedPackages(traitsOn: traits, manifests: loaded)
                    .filter { found[$0] != nil && $0 != id }
            case .failure:
                warnings.append("Couldn't read \(package.name)'s Package.swift, so its dependencies aren't shown.")
            case nil:
                break
            }
            nodes[id] = DependencyNode(id: id, name: package.name, version: pins[id]?.version,
                                       url: pins[id]?.location ?? package.url, children: children)
        }

        // "retrace.xcodeproj" can't clash with a package identity, even one named like the app.
        let rootID = project.lastPathComponent.lowercased()
        nodes[rootID] = DependencyNode(id: rootID, name: name, version: nil, url: project.path,
                                       children: direct.map(\.identity))
        return (DependencyGraph(rootID: rootID, nodes: nodes), warnings)
    }

    /// Packages in workspace-state.json in the project's DerivedData folder,
    /// or nil if Xcode hasn't resolved the project's packages yet.
    private func downloadedPackages(for project: URL) throws -> [DerivedData.Package]? {
        if let derivedData {
            guard let packages = DerivedData.packages(inSourcePackages: derivedData.appendingPathComponent("SourcePackages")) else {
                throw DepViewError.derivedDataNotFound(path: derivedData.path)
            }
            return packages
        }
        let root = derivedDataRoot ?? DerivedData.root(relativeTo: project)
        guard let folder = DerivedData.folder(for: project, in: root) else { return nil }
        return DerivedData.packages(inSourcePackages: folder.appendingPathComponent("SourcePackages"))
    }

    /// Each dump-package compiles a manifest and takes about a second, so they run in parallel.
    private func readManifests(_ packages: [(id: String, folder: URL)]) -> [String: Result<Manifest, any Error>] {
        let results = Locked<[String: Result<Manifest, any Error>]>([:])
        let reader = manifestReader
        DispatchQueue.concurrentPerform(iterations: packages.count) { index in
            let package = packages[index]
            let result = Result { try reader.manifest(ofPackageAt: package.folder) }
            results.withLock { $0[package.id] = result }
        }
        return results.withLock { $0 }
    }

    private struct Found {
        let name: String
        let url: String?
        let folder: URL?
    }
}

/// A value that several threads update, one at a time.
private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
