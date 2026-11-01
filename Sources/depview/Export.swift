import ArgumentParser
import DepViewCore
import Foundation

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Write the dependency graph as Mermaid, DOT or JSON.")

    enum Format: String, ExpressibleByArgument, CaseIterable {
        case mermaid, dot, json
    }

    @OptionGroup var project: ProjectOptions

    @Option(help: "Output format.")
    var format: Format = .mermaid

    @Option(name: .shortAndLong,
            help: ArgumentHelp("File to write. Without it, the graph is printed.", valueName: "file"),
            completion: .file())
    var output: String?

    func run() throws {
        let graph = try project.loadGraph()
        let text: String
        switch format {
        case .mermaid: text = MermaidRenderer().render(graph)
        case .dot: text = DotRenderer().render(graph)
        case .json: text = try JSONRenderer().render(graph)
        }

        guard let output else {
            print(text)
            return
        }
        do {
            try (text + "\n").write(to: URL(fileURLWithPath: output), atomically: true, encoding: .utf8)
        } catch {
            throw DepViewError.cannotWriteFile(path: output)
        }
        // stderr, so stdout stays empty when only the file was asked for.
        FileHandle.standardError.write(Data("Wrote \(output)\n".utf8))
    }
}
