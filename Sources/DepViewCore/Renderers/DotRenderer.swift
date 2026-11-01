/// Writes a graph in Graphviz DOT, e.g. for `dot -Tsvg graph.dot -o graph.svg`.
public struct DotRenderer {
    public init() {}

    public func render(_ graph: DependencyGraph) -> String {
        let nodes = graph.reachableNodes()
        var lines = ["digraph dependencies {", "    node [shape=box];"]
        for node in nodes {
            let label = escape(node.name) + (node.version.map { "\\n" + escape($0) } ?? "")
            lines.append("    \"\(escape(node.id))\" [label=\"\(label)\"];")
        }
        for node in nodes {
            for child in node.children where graph.nodes[child] != nil {
                lines.append("    \"\(escape(node.id))\" -> \"\(escape(child))\";")
            }
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
