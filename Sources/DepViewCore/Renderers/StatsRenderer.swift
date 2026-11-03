import Foundation

/// Prints `GraphStats` as aligned text, or as JSON for scripts.
public enum StatsRenderer {
    public static func text(_ stats: GraphStats, style: Style = .plain) -> String {
        var lines = [style.bold(stats.project)]
        guard stats.packages > 0 else { return lines[0] + "\nNo dependencies." }
        func row(_ label: String, _ value: String) {
            lines.append(style.dim(label.padding(toLength: 14, withPad: " ", startingAt: 0)) + value)
        }

        row("Packages", "\(stats.packages): " + (stats.transitive == 0 ? "all direct"
            : "\(stats.direct) direct, \(stats.transitive) through other packages"))
        row("From", [(stats.local, "local"), (stats.downloaded, "downloaded")]
            .filter { $0.0 > 0 }.map { "\($0.0) \($0.1)" }.joined(separator: ", "))
        row("Max depth", "\(stats.maxDepth)")
        if let shared = stats.mostShared {
            let usedBy = shared.packages.count == 1 ? "used by" : "each used by"
            row("Most shared", "\(shared.packages.joined(separator: ", ")), \(usedBy) \(shared.usedBy) packages")
        } else {
            row("Most shared", "none")
        }
        if !stats.licenses.isEmpty {
            // Most common first; "unknown" last, since it's the one to look into.
            let known = stats.licenses.filter { $0.key != "unknown" }
                .sorted { ($1.value, $0.key) < ($0.value, $1.key) }
                .map { "\($0.key) \($0.value)" }
            let unknown = stats.licenses["unknown"].map { [style.yellow("unknown \($0)")] } ?? []
            row("Licenses", (known + unknown).joined(separator: ", "))
        }

        if let most = stats.heaviest.first?.bringsIn {
            lines += ["", "Heaviest direct dependencies, by packages only they bring in"]
            let width = stats.heaviest.map(\.package.count).max() ?? 0
            for weight in stats.heaviest {
                let bar = String(repeating: "█", count: max(1, Int((Double(weight.bringsIn) / Double(most) * 20).rounded())))
                lines.append("  " + weight.package.padding(toLength: width, withPad: " ", startingAt: 0)
                             + "  " + style.cyan(bar) + " \(weight.bringsIn)")
            }
        }

        let warnings = stats.onBranch.map { "\($0.package) follows branch \($0.version), not a release." }
            + stats.onCommit.map { "\($0.package) is pinned to commit \($0.version), not a release." }
        if !warnings.isEmpty {
            lines += ["", "Watch out"] + warnings.map { "  " + style.yellow($0) }
        }
        return lines.joined(separator: "\n")
    }

    public static func json(_ stats: GraphStats) throws -> String {
        String(decoding: try JSONEncoder.depview.encode(stats), as: UTF8.self)
    }
}
