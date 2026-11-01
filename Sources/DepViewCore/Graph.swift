/// One package in a dependency graph.
public struct DependencyNode: Hashable, Sendable {
    public let id: String          // SPM identity, e.g. "swift-syntax"
    public let name: String
    public let version: String?
    public let url: String?
    public var children: [String]  // ids of direct dependencies
}

/// Every package reachable from the root, keyed by id.
public struct DependencyGraph: Sendable {
    public let rootID: String
    public var nodes: [String: DependencyNode]
}
