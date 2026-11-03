/// Terminal colors as ANSI escape codes. A disabled style returns text unchanged,
/// so output piped to a file or another command stays clean.
public struct Style: Sendable {
    public var isEnabled: Bool
    public init(isEnabled: Bool) { self.isEnabled = isEnabled }

    public static let plain = Style(isEnabled: false)
    public static let ansi = Style(isEnabled: true)

    /// Colors are on only when printing to a terminal, and off with --no-color,
    /// a non-empty NO_COLOR (https://no-color.org) or TERM=dumb.
    public static func automatic(noColor: Bool, isTerminal: Bool, environment: [String: String]) -> Style {
        Style(isEnabled: !noColor && isTerminal
              && (environment["NO_COLOR"] ?? "").isEmpty
              && environment["TERM"] != "dumb")
    }

    func bold(_ text: String) -> String { wrap(text, code: "1") }
    func dim(_ text: String) -> String { wrap(text, code: "2") }
    func cyan(_ text: String) -> String { wrap(text, code: "36") }
    func magenta(_ text: String) -> String { wrap(text, code: "35") }
    func yellow(_ text: String) -> String { wrap(text, code: "33") }

    /// A package's name: magenta for a local package, like the app's own modules.
    func name(_ node: DependencyNode) -> String { node.isLocal ? magenta(node.name) : node.name }

    /// A package's version: cyan for a release, yellow for a branch or a commit.
    func version(_ node: DependencyNode) -> String? {
        node.versionText.map { node.isUnreleased ? yellow($0) : cyan($0) }
    }

    private func wrap(_ text: String, code: String) -> String {
        isEnabled && !text.isEmpty ? "\u{1B}[\(code)m\(text)\u{1B}[0m" : text
    }
}
