import ArgumentParser
import DepViewCore
import Foundation

/// The project that every command reads.
struct ProjectOptions: ParsableArguments {
    @Argument(help: "Folder with Package.swift, an .xcodeproj or an .xcworkspace.")
    var path: String = "."

    @Option(help: ArgumentHelp("Xcode projects only: the DerivedData folder, if you built with xcodebuild -derivedDataPath.",
                               valueName: "folder"))
    var derivedData: String?

    func loadGraph() throws -> DependencyGraph {
        switch try ProjectDetector.detect(URL(fileURLWithPath: path)) {
        case .swiftPackage(let folder):
            return try SPMLoader().load(from: folder)
        case .xcode(let project):
            let loader = XcodeLoader(derivedData: derivedData.map { URL(fileURLWithPath: $0) })
            let (graph, warnings) = try loader.loadWithWarnings(from: project)
            for warning in warnings {
                FileHandle.standardError.write(Data("Warning: \(warning)\n".utf8))
            }
            return graph
        }
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
