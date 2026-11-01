/// The numbers `depview stats` prints.
public struct GraphStats: Equatable, Codable, Sendable {
    /// Packages the root depends on, directly or not. The root itself isn't counted.
    public let packages: Int
    public let direct: Int
    public let transitive: Int
    /// Steps in the longest chain from the root, e.g. 2 for App → A → B.
    public let maxDepth: Int
    /// The packages with the most direct dependents. nil when no package has more than one.
    public let mostShared: MostShared?

    public struct MostShared: Equatable, Codable, Sendable {
        /// Names in alphabetical order. Several when they tie.
        public let packages: [String]
        public let usedBy: Int
    }

    public init(graph: DependencyGraph) {
        packages = max(graph.reachableNodes().count - 1, 0)
        direct = Set(graph.nodes[graph.rootID]?.children ?? []).filter { graph.nodes[$0] != nil }.count
        transitive = packages - direct

        var memo: [String: Int] = [:]
        var visiting: Set<String> = []
        func depth(_ id: String) -> Int {
            if let known = memo[id] { return known }
            guard let node = graph.nodes[id], visiting.insert(id).inserted else { return 0 }  // A cycle: stop.
            let deepest = node.children.filter { graph.nodes[$0] != nil }.map { depth($0) + 1 }.max() ?? 0
            visiting.remove(id)
            memo[id] = deepest
            return deepest
        }
        maxDepth = depth(graph.rootID)

        let parents = graph.parents()
        let most = parents.values.map(\.count).max() ?? 0
        mostShared = most > 1
            ? MostShared(packages: parents.filter { $0.value.count == most }.compactMap { graph.nodes[$0.key]?.name }.sorted(),
                         usedBy: most)
            : nil
    }
}
