/// Prints a `why` result: the answer first (how many paths, what they all go through,
/// who uses the package directly), then the shortest paths.
public struct WhyRenderer {
    public var style: Style
    public init(style: Style = .plain) { self.style = style }

    public func render(_ result: WhyResult) -> String {
        let package = result.package
        var title = style.bold(package.name)
        if let version = style.version(package) { title += " " + version }
        if result.isRoot {
            return "\(title) is the root package, so nothing pulls it in."
        }
        guard result.totalPaths > 0 else {
            return "\(title) isn't reachable from the root package."
        }
        if let license = package.license { title += "  " + style.dim(license) }

        // The project in bold, as at the top of the tree; its own modules in their color.
        func name(_ node: DependencyNode) -> String {
            node.id == result.rootID ? style.bold(node.name) : style.name(node)
        }

        var lines = [title]
        if result.totalPaths == 1 {
            lines.append("Pulled in by 1 path.")
        } else if result.through.isEmpty {
            lines.append("Pulled in by \(result.totalPaths) paths.")
        } else {
            lines.append("Pulled in by \(result.totalPaths) paths, and every one goes through "
                         + list(result.through.map(name)) + ".")
        }

        let users = result.usedBy
        if users.count == 1, let user = users.first, !result.isDirect {
            lines.append("Only \(name(user)) uses it directly, so that's where to remove \(package.name).")
        } else if users.count == 1, let user = users.first {
            lines.append("\(name(user)) uses it directly.")
        } else {
            let shown = users.prefix(5).map(name)
            let more = users.count > 5 ? ["\(users.count - 5) more"] : []
            lines.append("Used directly by \(list(shown + more)).")
        }

        lines.append("")
        for path in result.paths {
            lines.append("  " + path.map(name).joined(separator: style.dim(" → ")))
        }
        let hidden = result.totalPaths - result.paths.count
        if hidden > 0 {
            lines.append(style.dim("  …and \(hidden) more. Pass --all to list them."))
        }
        return lines.joined(separator: "\n")
    }

    /// "A", "A and B", "A, B and C".
    private func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }
}
