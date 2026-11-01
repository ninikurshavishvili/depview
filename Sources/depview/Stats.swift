import ArgumentParser
import DepViewCore

struct Stats: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print a summary: package counts, depth and the most shared package."
    )

    @OptionGroup var project: ProjectOptions

    @Flag(help: "Print the summary as JSON.")
    var json = false

    func run() throws {
        let stats = GraphStats(graph: try project.loadGraph())
        if json {
            print(try StatsRenderer.json(stats))
        } else {
            print(StatsRenderer.text(stats))
        }
    }
}
