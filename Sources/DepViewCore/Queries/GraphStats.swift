/// The numbers `depview stats` prints.
public struct GraphStats: Equatable, Codable, Sendable {
    /// The root package's name.
    public let project: String
    /// Packages the root depends on, directly or not. The root itself isn't counted.
    public let packages: Int
    public let direct: Int
    public let transitive: Int
    /// Packages in a folder on this Mac, like an app's own modules, and downloaded ones.
    public let local: Int
    public let downloaded: Int
    /// Steps in the longest chain from the root, e.g. 2 for App → A → B.
    public let maxDepth: Int
    /// The packages with the most direct dependents. nil when no package has more than one.
    public let mostShared: MostShared?
    /// Up to five direct dependencies that bring in the most packages on their own,
    /// most first. Ones that bring in none aren't listed.
    public let heaviest: [Weight]
    /// How many downloaded packages have each license, "unknown" when depview couldn't tell.
    public let licenses: [String: Int]
    /// Packages that follow a branch or a single commit instead of a release.
    public let onBranch: [Pinned]
    public let onCommit: [Pinned]

    public struct MostShared: Equatable, Codable, Sendable {
        /// Names in alphabetical order. Several when they tie.
        public let packages: [String]
        public let usedBy: Int
    }

    public struct Weight: Equatable, Codable, Sendable {
        public let package: String
        /// Packages that are there only because of this one.
        public let bringsIn: Int
    }

    public struct Pinned: Equatable, Codable, Sendable {
        public let package: String
        /// The branch name or short commit hash.
        public let version: String
    }

    public init(graph: DependencyGraph) {
        let reachable = graph.reachableNodes().filter { $0.id != graph.rootID }
        project = graph.nodes[graph.rootID]?.name ?? graph.rootID
        packages = reachable.count
        let directIDs = (graph.nodes[graph.rootID]?.children ?? []).filter { graph.nodes[$0] != nil }
        direct = Set(directIDs).count
        transitive = packages - direct
        local = reachable.filter(\.isLocal).count
        downloaded = packages - local

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

        let dominators = Dominators(graph)
        heaviest = Array(directIDs.compactMap { id -> Weight? in
            let count = dominators.onlyThrough(id)
            return count > 0 ? graph.nodes[id].map { Weight(package: $0.name, bringsIn: count) } : nil
        }
        .sorted { ($1.bringsIn, $0.package) < ($0.bringsIn, $1.package) }
        .prefix(5))

        var licenses: [String: Int] = [:]
        for node in reachable where !node.isLocal { licenses[node.license ?? "unknown", default: 0] += 1 }
        self.licenses = licenses
        func pinned(_ pin: Pin) -> [Pinned] {
            reachable.filter { $0.pin == pin }.map { Pinned(package: $0.name, version: $0.version ?? "") }
                .sorted { $0.package < $1.package }
        }
        onBranch = pinned(.branch)
        onCommit = pinned(.commit)
    }
}
