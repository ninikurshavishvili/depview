/// Prints a `why` result: a summary line, then one line per path.
public struct WhyRenderer {
    public var style: Style
    public init(style: Style = .plain) { self.style = style }

    public func render(_ result: WhyResult) -> String {
        let package = result.package
        let title = style.bold(package.name) + (package.version.map { " " + style.cyan($0) } ?? "")
        if result.isRoot {
            return "\(title) is the root package, so nothing pulls it in."
        }
        guard result.totalPaths > 0 else {
            return "\(title) isn't reachable from the root package."
        }

        let noun = result.totalPaths == 1 ? "path" : "paths"
        var lines = ["\(title) is pulled in by \(result.totalPaths) \(noun):"]
        for path in result.paths {
            lines.append("  " + path.map(\.name).joined(separator: style.dim(" → ")))
        }
        let hidden = result.totalPaths - result.paths.count
        if hidden > 0 {
            lines.append(style.dim("  …and \(hidden) more. Pass --all to list them."))
        }
        return lines.joined(separator: "\n")
    }
}
