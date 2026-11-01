/// Writes a graph as a Mermaid flowchart, which GitHub renders inside Markdown.
public struct MermaidRenderer {
    public init() {}

    public func render(_ graph: DependencyGraph) -> String {
        let nodes = graph.reachableNodes()
        // Package names can't all be Mermaid ids (dots, or words like "end"),
        // so each package gets n0, n1, … and its name goes in the label.
        var ids: [String: String] = [:]
        for (index, node) in nodes.enumerated() { ids[node.id] = "n\(index)" }

        var lines = ["graph TD"]
        for (index, node) in nodes.enumerated() {
            lines.append("    n\(index)[\"\(label(node))\"]")
        }
        for (index, node) in nodes.enumerated() {
            for child in node.children {
                if let childID = ids[child] { lines.append("    n\(index) --> \(childID)") }
            }
        }
        return lines.joined(separator: "\n")
    }

    private func label(_ node: DependencyNode) -> String {
        let text = node.version.map { "\(node.name) \($0)" } ?? node.name
        return text.replacingOccurrences(of: "\"", with: "#quot;")
    }
}
