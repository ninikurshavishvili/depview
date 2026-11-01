import ArgumentParser
import DepViewCore
import Foundation

struct Tree: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print the dependency tree.")

    @Argument(help: "Folder containing Package.swift.")
    var path: String = "."

    @Option(help: "Maximum depth to print (1 = direct dependencies only).")
    var depth: Int?

    func validate() throws {
        if let depth, depth < 1 {
            throw ValidationError("--depth must be 1 or more.")
        }
    }

    func run() throws {
        let folder = URL(fileURLWithPath: path)
        let graph = try SPMLoader().load(from: folder)
        print(TreeRenderer(maxDepth: depth).render(graph))
    }
}
