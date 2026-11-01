/// Draws a graph as an indented tree with box-drawing characters.
public struct TreeRenderer {
    public var maxDepth: Int?
    public init(maxDepth: Int? = nil) { self.maxDepth = maxDepth }

    public func render(_ graph: DependencyGraph) -> String {
        guard let root = graph.nodes[graph.rootID] else { return "" }
        var lines = [root.name]
        // Packages whose children are already printed. A package cut off by maxDepth
        // isn't added, so a later, shallower copy still shows its children.
        var expanded: Set<String> = [root.id]

        func walk(_ node: DependencyNode, prefix: String, depth: Int) {
            let kids = node.children.compactMap { graph.nodes[$0] }
            for (index, child) in kids.enumerated() {
                let isLast = index == kids.count - 1
                let version = child.version.map { " \($0)" } ?? ""
                let shownAbove = expanded.contains(child.id)
                lines.append(prefix + (isLast ? "└── " : "├── ")
                             + child.name + version
                             + (shownAbove ? " (seen above)" : ""))
                let canExpand = maxDepth.map { depth < $0 } ?? true
                if canExpand && !shownAbove {
                    expanded.insert(child.id)
                    walk(child, prefix: prefix + (isLast ? "    " : "│   "), depth: depth + 1)
                }
            }
        }

        walk(root, prefix: "", depth: 1)
        return lines.joined(separator: "\n")
    }
}
