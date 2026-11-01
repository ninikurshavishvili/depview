/// Draws a graph as an indented tree with box-drawing characters.
public struct TreeRenderer {
    public var maxDepth: Int?
    public var showVersions: Bool
    public var style: Style

    public init(maxDepth: Int? = nil, showVersions: Bool = true, style: Style = .plain) {
        self.maxDepth = maxDepth
        self.showVersions = showVersions
        self.style = style
    }

    public func render(_ graph: DependencyGraph) -> String {
        guard let root = graph.nodes[graph.rootID] else { return "" }
        var lines = [style.bold(root.name)]
        // Packages whose children are already printed. A package cut off by maxDepth
        // isn't added, so a later, shallower copy still shows its children.
        var expanded: Set<String> = [root.id]

        func walk(_ node: DependencyNode, prefix: String, depth: Int) {
            let kids = node.children.compactMap { graph.nodes[$0] }
            for (index, child) in kids.enumerated() {
                let isLast = index == kids.count - 1
                let shownAbove = expanded.contains(child.id)
                var line = style.dim(prefix + (isLast ? "└── " : "├── ")) + child.name
                if showVersions, let version = child.version { line += " " + style.cyan(version) }
                if shownAbove { line += " " + style.dim("(seen above)") }
                lines.append(line)
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
