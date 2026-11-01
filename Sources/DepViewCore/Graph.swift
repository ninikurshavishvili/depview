/// One package in a dependency graph.
public struct DependencyNode: Hashable, Sendable {
    public let id: String          // SPM identity, e.g. "swift-syntax"
    public let name: String
    public let version: String?
    public let url: String?
    public var children: [String]  // ids of direct dependencies
}

/// Every package reachable from the root, keyed by id.
public struct DependencyGraph: Sendable {
    public let rootID: String
    public var nodes: [String: DependencyNode]
}

extension DependencyGraph {
    /// Every package reachable from the root, each once, in the order a depth-first
    /// walk meets them. Exports use this order, so their output is the same every run.
    func reachableNodes() -> [DependencyNode] {
        var order: [DependencyNode] = []
        var seen: Set<String> = []
        func visit(_ id: String) {
            guard let node = nodes[id], seen.insert(id).inserted else { return }
            order.append(node)
            node.children.forEach(visit)
        }
        visit(rootID)
        return order
    }

    /// For each reachable package, the ids of the packages that depend on it directly.
    func parents() -> [String: [String]] {
        var parents: [String: [String]] = [:]
        for node in reachableNodes() {
            for child in node.children where nodes[child] != nil {
                if parents[child]?.contains(node.id) != true {
                    parents[child, default: []].append(node.id)
                }
            }
        }
        return parents
    }
}
