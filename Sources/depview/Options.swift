import ArgumentParser
import DepViewCore
import Foundation

/// The project folder that every command reads.
struct ProjectOptions: ParsableArguments {
    @Argument(help: "Folder containing Package.swift.")
    var path: String = "."

    func loadGraph() throws -> DependencyGraph {
        try SPMLoader().load(from: URL(fileURLWithPath: path))
    }
}

/// --no-color, for commands that print colored text.
struct ColorOptions: ParsableArguments {
    @Flag(help: "Print without colors. Colors are also off when the output isn't a terminal or NO_COLOR is set.")
    var noColor = false

    var style: Style {
        .automatic(noColor: noColor,
                   isTerminal: isatty(STDOUT_FILENO) == 1,
                   environment: ProcessInfo.processInfo.environment)
    }
}
