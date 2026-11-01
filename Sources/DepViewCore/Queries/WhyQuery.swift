/// Finds the chains of packages that pull a package into the graph.
public struct WhyQuery {
    public static let defaultLimit = 20

    /// The most paths to list. nil lists them all.
    public var limit: Int?
    public init(limit: Int? = WhyQuery.defaultLimit) { self.limit = limit }

    /// Looks the package up by identity or name, ignoring case.
    public func run(_ package: String, in graph: DependencyGraph) throws -> WhyResult {
        guard let target = Self.find(package, in: graph) else {
            throw DepViewError.packageNotFound(name: package, suggestions: Self.suggestions(for: package, in: graph))
        }
        guard target.id != graph.rootID else {
            return WhyResult(package: target, paths: [], totalPaths: 0, isRoot: true)
        }

        // Only packages that lead to the target are worth walking into.
        let parents = graph.parents()
        var leadsToTarget: Set<String> = [target.id]
        var queue = [target.id]
        while let id = queue.popLast() {
            for parent in parents[id, default: []] where leadsToTarget.insert(parent).inserted {
                queue.append(parent)
            }
        }

        // Breadth-first, so the shortest paths come first and survive the limit.
        var found: [[String]] = []
        var frontier = [[graph.rootID]]
        while !frontier.isEmpty && found.count < (limit ?? .max) {
            var next: [[String]] = []
            for path in frontier {
                for child in graph.nodes[path[path.count - 1]]?.children ?? []
                where leadsToTarget.contains(child) && !path.contains(child) {
                    if child == target.id { found.append(path + [child]) } else { next.append(path + [child]) }
                }
            }
            frontier = next
        }
        if let limit { found = Array(found.prefix(limit)) }

        let total = found.count == limit ? Self.countPaths(to: target.id, in: graph, through: leadsToTarget) : found.count
        let paths = found.map { path in path.compactMap { graph.nodes[$0] } }
        return WhyResult(package: target, paths: paths, totalPaths: max(total, found.count), isRoot: false)
    }

    static func find(_ query: String, in graph: DependencyGraph) -> DependencyNode? {
        let key = query.lowercased()
        return graph.nodes[key]
            ?? graph.nodes.values.filter { $0.name.lowercased() == key }.min { $0.id < $1.id }
    }

    /// Up to three package names close to `query`, for a "Did you mean" hint.
    static func suggestions(for query: String, in graph: DependencyGraph) -> [String] {
        let key = query.lowercased()
        let scored = graph.nodes.values.compactMap { node -> (related: Bool, distance: Int, name: String)? in
            let related = !key.isEmpty && (node.id.contains(key) || key.contains(node.id))
            let distance = min(editDistance(key, node.id), editDistance(key, node.name.lowercased()))
            guard related || distance <= max(2, key.count / 3) else { return nil }
            return (related, distance, node.name)
        }
        return scored
            .sorted { ($0.related ? 0 : 1, $0.distance, $0.name) < ($1.related ? 0 : 1, $1.distance, $1.name) }
            .prefix(3)
            .map(\.name)
    }

    /// Counts paths without listing them, so a graph with millions of paths stays fast.
    private static func countPaths(to target: String, in graph: DependencyGraph, through allowed: Set<String>) -> Int {
        var memo: [String: Int] = [target: 1]
        var visiting: Set<String> = []
        func count(_ id: String) -> Int {
            if let known = memo[id] { return known }
            guard visiting.insert(id).inserted else { return 0 }  // A cycle: don't loop.
            let children = (graph.nodes[id]?.children ?? []).filter(allowed.contains)
            let total = children.reduce(0) { sum, child in
                let (added, overflow) = sum.addingReportingOverflow(count(child))
                return overflow ? .max : added
            }
            visiting.remove(id)
            memo[id] = total
            return total
        }
        return count(graph.rootID)
    }
}

/// What `WhyQuery` found for one package.
public struct WhyResult: Equatable, Sendable {
    public let package: DependencyNode
    /// Paths from the root to the package, shortest first. Each starts with the root.
    public let paths: [[DependencyNode]]
    /// How many paths there are in all. More than `paths.count` when the list was cut off.
    public let totalPaths: Int
    public let isRoot: Bool
}

/// The number of single-character edits that turn `a` into `b`.
private func editDistance(_ a: String, _ b: String) -> Int {
    let b = Array(b)
    var row = Array(0...b.count)
    for (i, x) in a.enumerated() {
        var diagonal = row[0]
        row[0] = i + 1
        for (j, y) in b.enumerated() {
            let above = row[j + 1]
            row[j + 1] = x == y ? diagonal : 1 + min(diagonal, row[j], above)
            diagonal = above
        }
    }
    return row[b.count]
}
