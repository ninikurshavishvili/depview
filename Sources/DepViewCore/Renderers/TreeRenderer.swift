/// Draws a graph as an indented tree with box-drawing characters.
public struct TreeRenderer {
    public var maxDepth: Int?
    public var showVersions: Bool
    /// The counts after the root's name.
    public var showSummary: Bool
    public var style: Style

    public init(maxDepth: Int? = nil, showVersions: Bool = true, showSummary: Bool = true, style: Style = .plain) {
        self.maxDepth = maxDepth
        self.showVersions = showVersions
        self.showSummary = showSummary
        self.style = style
    }

    public func render(_ graph: DependencyGraph) -> String {
        guard let root = graph.nodes[graph.rootID] else { return "" }
        let dominators = Dominators(graph)
        var lines = [Line(text: style.bold(root.name) + (showSummary ? "  " + style.dim(summary(graph)) : ""),
                          width: 0, weight: 0)]
        // Packages whose children are already printed. A package cut off by maxDepth
        // isn't added, so a later, shallower copy still shows its children.
        var expanded: Set<String> = [root.id]
        // Packages printed at the depth limit, without their children.
        var cutOff: Set<String> = []

        // First decide what each package shows, in the order the tree is read: a package
        // drawn earlier, even by an earlier sibling's children, folds into the "↑" line.
        func build(_ node: DependencyNode, depth: Int) -> Item {
            var item = Item(node: node)
            let canExpand = maxDepth.map { depth < $0 } ?? true
            for child in node.children.compactMap({ graph.nodes[$0] }) {
                if expanded.contains(child.id) || (!canExpand && cutOff.contains(child.id)) {
                    item.shownAbove.append(child.name)
                } else if canExpand {
                    expanded.insert(child.id)
                    item.children.append(build(child, depth: depth + 1))
                } else {
                    cutOff.insert(child.id)
                    item.children.append(Item(node: child))
                }
            }
            return item
        }

        // Then draw it, now that it's known which line comes last under each package.
        func draw(_ item: Item, prefix: String) {
            for (index, child) in item.children.enumerated() {
                let isLast = index == item.children.count - 1 && item.shownAbove.isEmpty
                let branch = prefix + (isLast ? "└── " : "├── ")
                var text = style.dim(branch) + style.name(child.node)
                var width = branch.count + child.node.name.count
                if showVersions, let version = child.node.versionText {
                    text += " " + (style.version(child.node) ?? version)
                    width += 1 + version.count
                }
                lines.append(Line(text: text, width: width, weight: dominators.onlyThrough(child.node.id)))
                draw(child, prefix: prefix + (isLast ? "    " : "│   "))
            }
            if !item.shownAbove.isEmpty {
                lines.append(Line(text: style.dim(prefix + "└── ↑ " + item.shownAbove.joined(separator: ", ")),
                                  width: 0, weight: 0))
            }
        }

        draw(build(root, depth: 1), prefix: "")

        // "+N" lines up in one column, unless a line is too long for it.
        let column = min(lines.filter { $0.weight > 0 }.map(\.width).max() ?? 0, 56) + 2
        return lines.map { line in
            guard line.weight > 0 else { return line.text }
            return line.text + String(repeating: " ", count: max(column - line.width, 2)) + style.dim("+\(line.weight)")
        }.joined(separator: "\n")
    }

    /// E.g. "31 packages · 16 direct · 9 levels · 1 on a branch".
    private func summary(_ graph: DependencyGraph) -> String {
        let stats = GraphStats(graph: graph)
        guard stats.packages > 0 else { return "no dependencies" }
        var parts = [counted(stats.packages, "package"), "\(stats.direct) direct", counted(stats.maxDepth, "level")]
        if !stats.onBranch.isEmpty { parts.append("\(stats.onBranch.count) on a branch") }
        if !stats.onCommit.isEmpty { parts.append("\(stats.onCommit.count) on a commit") }
        return parts.joined(separator: " · ")
    }

    private struct Item {
        let node: DependencyNode
        var children: [Item] = []
        /// Names of children already drawn above, for the "↑" line.
        var shownAbove: [String] = []
    }

    private struct Line {
        let text: String
        /// Characters before the weight, not counting escape codes.
        let width: Int
        /// Packages only this one brings in; 0 shows nothing.
        let weight: Int
    }
}

/// "1 package", "2 packages".
func counted(_ count: Int, _ noun: String) -> String {
    "\(count) \(noun)\(count == 1 ? "" : "s")"
}
