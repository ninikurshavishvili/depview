import ArgumentParser
import DepViewCore
import Foundation

@main
struct DepView: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "depview",
        abstract: "Visualize Swift package dependencies.",
        version: "1.0.0",
        subcommands: [Tree.self, Why.self, Export.self, Stats.self],
        defaultSubcommand: Tree.self
    )

    // Argument Parser exits with 1 for every error, so depview's own errors are printed
    // here to exit with their own code. Help, --version and usage errors work as before.
    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch let error as DepViewError {
            FileHandle.standardError.write(Data("Error: \(error.message)\nHint: \(error.hint)\n".utf8))
            Foundation.exit(error.exitCode)
        } catch {
            exit(withError: error)
        }
    }
}
