import Foundation

/// Writes a graph as JSON in depview's own flat format: one entry per package,
/// each listing the ids it depends on.
public struct JSONRenderer {
    /// Goes up when the format changes in a way that breaks existing readers.
    public static let schemaVersion = 1

    public init() {}

    public func render(_ graph: DependencyGraph) throws -> String {
        let document = Document(schemaVersion: Self.schemaVersion,
                                root: graph.rootID,
                                packages: graph.reachableNodes().map { node in
                                    Package(node, dependencies: node.children.filter { graph.nodes[$0] != nil })
                                })
        return String(decoding: try JSONEncoder.depview.encode(document), as: UTF8.self)
    }

    private struct Document: Encodable {
        let schemaVersion: Int
        let root: String
        let packages: [Package]
    }

    private struct Package: Encodable {
        let id: String
        let name: String
        let version: String?
        /// "release", "branch" or "commit"; null for a local package.
        let pin: Pin?
        let url: String?
        let license: String?
        let dependencies: [String]

        init(_ node: DependencyNode, dependencies: [String]) {
            id = node.id
            name = node.name
            version = node.version
            pin = node.pin
            url = node.url
            license = node.license
            self.dependencies = dependencies
        }

        // Writes null for anything missing, so every entry has the same keys.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(version, forKey: .version)
            try container.encode(pin, forKey: .pin)
            try container.encode(url, forKey: .url)
            try container.encode(license, forKey: .license)
            try container.encode(dependencies, forKey: .dependencies)
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, version, pin, url, license, dependencies
        }
    }
}

extension JSONEncoder {
    /// Sorted keys, so JSON output is the same on every run and macOS version.
    static var depview: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
