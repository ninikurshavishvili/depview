import Foundation

/// Loads a Swift package's resolved dependencies with `swift package show-dependencies`.
public struct SPMLoader: GraphLoader {
    public init() {}

    public func load(from folder: URL) throws -> DependencyGraph {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isFolder), isFolder.boolValue else {
            throw DepViewError.folderNotFound(path: folder.path)
        }
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("Package.swift").path) else {
            throw DepViewError.noPackageManifest(path: folder.path)
        }
        let output = try SwiftCLI.run(["package", "show-dependencies", "--format", "json"], in: folder)
        // SwiftPM calls a branch or commit "unspecified"; Package.resolved says which it is.
        let pins = (try? Data(contentsOf: folder.appendingPathComponent("Package.resolved")))
            .flatMap(PackageResolved.pins(from:)) ?? []
        return try Self.parse(output, pins: pins, readsLicenses: true)
    }

    /// Builds a graph from the JSON that `show-dependencies --format json` prints. With
    /// `readsLicenses`, each package's license comes from the license file in its folder.
    static func parse(_ output: Data, pins: [PackagePin] = [], readsLicenses: Bool = false) throws -> DependencyGraph {
        // SwiftPM may print "Fetching..." lines before the JSON: skip to the first "{".
        guard let start = output.firstIndex(of: UInt8(ascii: "{")),
              let root = try? JSONDecoder().decode(SPMNode.self, from: Data(output[start...])) else {
            throw DepViewError.unreadableOutput
        }
        let pinned = Dictionary(pins.map { ($0.identity, $0) }, uniquingKeysWith: { first, _ in first })
        var nodes: [String: DependencyNode] = [:]

        func visit(_ node: SPMNode) {
            guard nodes[node.identity] == nil else { return }
            let isSpecified = node.version != "unspecified"
            nodes[node.identity] = DependencyNode(
                id: node.identity,
                name: node.name,
                version: isSpecified ? node.version : pinned[node.identity]?.version,
                url: node.url,
                children: node.dependencies.map(\.identity),
                pin: isSpecified ? .release : pinned[node.identity]?.pin,
                license: readsLicenses && node.identity != root.identity
                    ? node.path.flatMap { LicenseFile.license(inPackageAt: URL(fileURLWithPath: $0)) } : nil
            )
            node.dependencies.forEach(visit)
        }

        visit(root)
        return DependencyGraph(rootID: root.identity, nodes: nodes)
    }
}

private struct SPMNode: Decodable {
    let identity: String
    let name: String
    let url: String
    let version: String
    let path: String?
    let dependencies: [SPMNode]
}
