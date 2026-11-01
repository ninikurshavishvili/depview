import Foundation
import Testing
@testable import DepViewCore

/// Reads `Fixtures/<name>.json`, real output saved from `swift package show-dependencies`.
func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

/// Builds a graph from an adjacency list, using each id as its name.
func makeGraph(root: String, edges: [String: [String]]) -> DependencyGraph {
    var nodes: [String: DependencyNode] = [:]
    for (id, children) in edges {
        nodes[id] = DependencyNode(id: id, name: id, version: nil, url: nil, children: children)
    }
    return DependencyGraph(rootID: root, nodes: nodes)
}
