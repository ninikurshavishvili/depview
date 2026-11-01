import Foundation

/// Reads a project folder into a dependency graph.
public protocol GraphLoader {
    func load(from folder: URL) throws -> DependencyGraph
}
