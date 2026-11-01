import Foundation
import Testing
@testable import DepViewCore

/// Reads `Fixtures/<name>.json`, real output saved from `swift package show-dependencies`.
func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

/// The Fixtures folder in the source tree. Snapshots are read from here instead
/// of Bundle.module, because a missing snapshot is written back here.
private let fixturesFolder = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")

/// Compares `output` with `Fixtures/<fileName>`, e.g. "spm-medium.tree.txt". If that file
/// doesn't exist, writes it and fails, so you can check the new snapshot and run the tests again.
func expectSnapshot(_ output: String, named fileName: String,
                    sourceLocation: SourceLocation = #_sourceLocation) throws {
    let file = fixturesFolder.appendingPathComponent(fileName)
    guard FileManager.default.fileExists(atPath: file.path) else {
        try (output + "\n").write(to: file, atomically: true, encoding: .utf8)
        Issue.record(Comment(rawValue: "Wrote a new snapshot, Fixtures/\(fileName). Check it, then run the tests again."),
                     sourceLocation: sourceLocation)
        return
    }

    var expected = try String(contentsOf: file, encoding: .utf8)
    if expected.hasSuffix("\n") { expected.removeLast() }
    guard output != expected else { return }

    // Point at the first line that differs; big trees are hard to compare by eye.
    let expectedLines = expected.split(separator: "\n", omittingEmptySubsequences: false)
    let outputLines = output.split(separator: "\n", omittingEmptySubsequences: false)
    let index = zip(expectedLines, outputLines).prefix { $0 == $1 }.count
    func line(_ lines: [Substring]) -> String {
        index < lines.count ? String(lines[index]) : "(no more lines)"
    }
    Issue.record(Comment(rawValue: """
        Output doesn't match Fixtures/\(fileName) at line \(index + 1).
          expected: \(line(expectedLines))
          actual:   \(line(outputLines))
        If the new output is right, delete the file and run the tests again.
        """), sourceLocation: sourceLocation)
}

/// Builds a graph from an adjacency list, using each id as its name.
func makeGraph(root: String, edges: [String: [String]]) -> DependencyGraph {
    var nodes: [String: DependencyNode] = [:]
    for (id, children) in edges {
        nodes[id] = DependencyNode(id: id, name: id, version: nil, url: nil, children: children)
    }
    return DependencyGraph(rootID: root, nodes: nodes)
}
