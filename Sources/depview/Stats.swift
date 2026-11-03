import ArgumentParser
import DepViewCore

struct Stats: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print a summary: package counts, depth, licenses, the heaviest dependencies and what to watch out for."
    )

    @OptionGroup var project: ProjectOptions

    @Flag(help: "Print the summary as JSON.")
    var json = false

    @OptionGroup var color: ColorOptions

    func run() throws {
        let stats = GraphStats(graph: try project.loadGraph())
        if json {
            print(try StatsRenderer.json(stats))
        } else {
            print(StatsRenderer.text(stats, style: color.style))
        }
    }
}
