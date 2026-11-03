import ArgumentParser
import DepViewCore

struct Why: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show why a package is in the project: what every path goes through, who uses it, and the paths."
    )

    @Argument(help: "Package name or identity, e.g. swift-syntax.")
    var package: String

    @OptionGroup var project: ProjectOptions

    @Flag(help: "List every path, not only the \(WhyQuery.defaultLimit) shortest.")
    var all = false

    @OptionGroup var color: ColorOptions

    func run() throws {
        let graph = try project.loadGraph()
        let result = try WhyQuery(limit: all ? nil : WhyQuery.defaultLimit).run(package, in: graph)
        print(WhyRenderer(style: color.style).render(result))
    }
}
