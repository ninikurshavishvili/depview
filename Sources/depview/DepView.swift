import ArgumentParser

@main
struct DepView: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "depview",
        abstract: "Visualize Swift package dependencies.",
        version: "0.1.0",
        subcommands: [Tree.self],
        defaultSubcommand: Tree.self
    )
}
