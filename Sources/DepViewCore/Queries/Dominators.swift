/// The packages that lie on every path from the root to a package. If every path to X
/// goes through D, X is only there because of D: removing D would remove X too.
///
/// Uses the iterative algorithm from Cooper, Harvey and Kennedy, "A Simple, Fast
/// Dominance Algorithm" (2001), which also copes with cycles.
struct Dominators {
    private let rootID: String
    /// For each reachable package, the nearest package on every path to it. The root for
    /// a package the root uses directly, or reaches by several unrelated paths.
    private var immediate: [String: String] = [:]
    private var onlyThroughCount: [String: Int] = [:]

    init(_ graph: DependencyGraph) {
        rootID = graph.rootID

        // Postorder numbers: a package is numbered after everything below it.
        var postorder: [String] = []
        var visited: Set<String> = []
        func visit(_ id: String) {
            guard visited.insert(id).inserted, let node = graph.nodes[id] else { return }
            for child in node.children where graph.nodes[child] != nil { visit(child) }
            postorder.append(id)
        }
        visit(rootID)
        let number = Dictionary(uniqueKeysWithValues: postorder.enumerated().map { ($1, $0) })
        let parents = graph.parents()

        var immediate = [rootID: rootID]
        func intersect(_ a: String, _ b: String) -> String {
            var a = a, b = b
            while a != b {
                while number[a, default: 0] < number[b, default: 0] { a = immediate[a] ?? rootID }
                while number[b, default: 0] < number[a, default: 0] { b = immediate[b] ?? rootID }
            }
            return a
        }
        var changed = true
        while changed {
            changed = false
            for id in postorder.reversed() where id != rootID {
                let known = parents[id, default: []].filter { immediate[$0] != nil }
                guard var nearest = known.first else { continue }
                for parent in known.dropFirst() { nearest = intersect(parent, nearest) }
                if immediate[id] != nearest {
                    immediate[id] = nearest
                    changed = true
                }
            }
        }
        self.immediate = immediate

        // Children in the dominator tree, then subtree sizes, deepest first.
        var dominated: [String: [String]] = [:]
        for (id, dominator) in immediate where id != rootID { dominated[dominator, default: []].append(id) }
        var size: [String: Int] = [:]
        for id in postorder {
            size[id] = 1 + dominated[id, default: []].reduce(0) { $0 + size[$1, default: 1] }
        }
        onlyThroughCount = size.mapValues { $0 - 1 }
    }

    /// The packages every path to `id` goes through, nearest the root first,
    /// leaving out the root and `id` itself.
    func through(_ id: String) -> [String] {
        var chain: [String] = []
        var current = immediate[id]
        while let dominator = current, dominator != rootID {
            chain.append(dominator)
            current = immediate[dominator]
        }
        return chain.reversed()
    }

    /// How many packages are there only because of `id`.
    func onlyThrough(_ id: String) -> Int {
        onlyThroughCount[id, default: 0]
    }
}
