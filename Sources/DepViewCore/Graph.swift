/// How Package.resolved chose a package's version.
public enum Pin: String, Codable, Sendable {
    case release, branch, commit
}

/// One package in a dependency graph.
public struct DependencyNode: Hashable, Sendable {
    public let id: String          // SPM identity, e.g. "swift-syntax"
    public let name: String
    /// A release number, a branch name or a short commit hash; `pin` says which.
    public let version: String?
    public let url: String?
    public var children: [String]  // ids of direct dependencies
    /// nil for a package in a local folder, which isn't pinned.
    public var pin: Pin? = nil
    /// The license's SPDX id, e.g. "MIT", from the package's license file. nil when unknown.
    public var license: String? = nil
}

extension DependencyNode {
    /// A package in a folder on this Mac, like an app's own modules, not one downloaded from a URL.
    public var isLocal: Bool { url?.hasPrefix("/") ?? false }

    /// The version as depview prints it: "1.2.3", "branch main" or "commit 0687f71".
    public var versionText: String? {
        guard let version else { return nil }
        switch pin {
        case .branch: return "branch \(version)"
        case .commit: return "commit \(version)"
        case .release, nil: return version
        }
    }

    /// True when the package follows a branch or a commit instead of a release.
    var isUnreleased: Bool { pin == .branch || pin == .commit }
}

/// Every package reachable from the root, keyed by id.
public struct DependencyGraph: Sendable {
    public let rootID: String
    public var nodes: [String: DependencyNode]
}

extension DependencyGraph {
    /// Every package reachable from the root, each once, in the order a depth-first
    /// walk meets them. Exports use this order, so their output is the same every run.
    func reachableNodes() -> [DependencyNode] {
        var order: [DependencyNode] = []
        var seen: Set<String> = []
        func visit(_ id: String) {
            guard let node = nodes[id], seen.insert(id).inserted else { return }
            order.append(node)
            node.children.forEach(visit)
        }
        visit(rootID)
        return order
    }

    /// For each reachable package, the ids of the packages that depend on it directly.
    func parents() -> [String: [String]] {
        var parents: [String: [String]] = [:]
        for node in reachableNodes() {
            for child in node.children where nodes[child] != nil {
                if parents[child]?.contains(node.id) != true {
                    parents[child, default: []].append(node.id)
                }
            }
        }
        return parents
    }
}
