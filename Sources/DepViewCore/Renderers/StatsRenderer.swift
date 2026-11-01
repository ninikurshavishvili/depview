import Foundation

/// Prints `GraphStats` as aligned text, or as JSON for scripts.
public enum StatsRenderer {
    public static func text(_ stats: GraphStats) -> String {
        var lines = [
            "Packages:     \(stats.packages)  (\(stats.direct) direct, \(stats.transitive) transitive)",
            "Max depth:    \(stats.maxDepth)",
        ]
        if let shared = stats.mostShared {
            let usedBy = shared.packages.count == 1 ? "used by" : "each used by"
            lines.append("Most shared:  \(shared.packages.joined(separator: ", ")) (\(usedBy) \(shared.usedBy) packages)")
        } else {
            lines.append("Most shared:  none")
        }
        return lines.joined(separator: "\n")
    }

    public static func json(_ stats: GraphStats) throws -> String {
        String(decoding: try JSONEncoder.depview.encode(stats), as: UTF8.self)
    }
}
