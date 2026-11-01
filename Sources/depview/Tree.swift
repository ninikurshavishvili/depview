import ArgumentParser
import DepViewCore

struct Tree: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print the dependency tree.")

    @OptionGroup var project: ProjectOptions

    @Option(help: "Maximum depth to print (1 = direct dependencies only).")
    var depth: Int?

    @Flag(help: "Hide version numbers.")
    var noVersions = false

    @OptionGroup var color: ColorOptions

    func validate() throws {
        if let depth, depth < 1 {
            throw ValidationError("--depth must be 1 or more.")
        }
    }

    func run() throws {
        let graph = try project.loadGraph()
        let renderer = TreeRenderer(maxDepth: depth, showVersions: !noVersions, style: color.style)
        print(renderer.render(graph))
    }
}
