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
        return try Self.parse(output)
    }

    /// Builds a graph from the JSON that `show-dependencies --format json` prints.
    static func parse(_ output: Data) throws -> DependencyGraph {
        // SwiftPM may print "Fetching..." lines before the JSON: skip to the first "{".
        guard let start = output.firstIndex(of: UInt8(ascii: "{")),
              let root = try? JSONDecoder().decode(SPMNode.self, from: Data(output[start...])) else {
            throw DepViewError.unreadableOutput
        }
        var nodes: [String: DependencyNode] = [:]

        func visit(_ node: SPMNode) {
            guard nodes[node.identity] == nil else { return }
            nodes[node.identity] = DependencyNode(
                id: node.identity,
                name: node.name,
                version: node.version == "unspecified" ? nil : node.version,
                url: node.url,
                children: node.dependencies.map(\.identity)
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
    let dependencies: [SPMNode]
}
