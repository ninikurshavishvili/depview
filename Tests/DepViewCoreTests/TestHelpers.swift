import Foundation
import Testing
@testable import DepViewCore

/// Reads `Fixtures/<name>.<pathExtension>`, e.g. real output saved from `swift package show-dependencies`.
func fixture(_ name: String, withExtension pathExtension: String = "json") throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: pathExtension, subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

/// A new, empty folder in the temporary directory.
func temporaryFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

/// A throwaway Demo app in a temporary folder, built from the xcode-* fixtures. Demo uses
/// swift-dependencies and two local packages: Packages/Feature, a package reference, and
/// Packages/Settings, a folder dragged into the project. Packages/Logging is a folder too,
/// but no target links it; only Settings uses it. The workspace also lists a Tools package
/// folder. When `resolved`, Demo also gets a DerivedData folder like the one Xcode makes,
/// with empty checkouts.
struct DemoProject {
    let folder: URL
    let isWorkspace: Bool

    var project: URL { folder.appendingPathComponent(isWorkspace ? "Demo.xcworkspace" : "Demo.xcodeproj") }
    var derivedDataRoot: URL { folder.appendingPathComponent("DerivedData") }
    var derivedData: URL { derivedDataRoot.appendingPathComponent("Demo-fixturehash") }

    init(resolved: Bool = true, workspace: Bool = false) throws {
        let fileManager = FileManager.default
        folder = try temporaryFolder()
        isWorkspace = workspace

        let xcodeproj = folder.appendingPathComponent("Demo.xcodeproj")
        try fileManager.createDirectory(at: xcodeproj, withIntermediateDirectories: true)
        try fixture("xcode-demo", withExtension: "pbxproj").write(to: xcodeproj.appendingPathComponent("project.pbxproj"))
        // Only a folder with a Package.swift is a package; Assets is a plain folder.
        for name in ["Packages/Feature", "Packages/Settings", "Packages/Logging", "Assets"] {
            try fileManager.createDirectory(at: folder.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        for name in ["Settings", "Logging"] {
            try Data().write(to: folder.appendingPathComponent("Packages/\(name)/Package.swift"))
        }

        // A CocoaPods workspace lists the app project, Pods/Pods.xcodeproj and a Tools package,
        // and holds Package.resolved.
        let swiftpm: URL
        if workspace {
            try fileManager.createDirectory(at: folder.appendingPathComponent("Pods/Pods.xcodeproj"),
                                            withIntermediateDirectories: true)
            try fileManager.createDirectory(at: folder.appendingPathComponent("Tools"), withIntermediateDirectories: true)
            try Data().write(to: folder.appendingPathComponent("Tools/Package.swift"))
            swiftpm = project.appendingPathComponent("xcshareddata/swiftpm")
            try fileManager.createDirectory(at: swiftpm, withIntermediateDirectories: true)
            try Data("""
                <?xml version="1.0" encoding="UTF-8"?>
                <Workspace
                   version = "1.0">
                   <FileRef
                      location = "group:Demo.xcodeproj">
                   </FileRef>
                   <FileRef
                      location = "group:Pods/Pods.xcodeproj">
                   </FileRef>
                   <FileRef
                      location = "group:Tools">
                   </FileRef>
                </Workspace>
                """.utf8).write(to: project.appendingPathComponent("contents.xcworkspacedata"))
        } else {
            swiftpm = xcodeproj.appendingPathComponent("project.xcworkspace/xcshareddata/swiftpm")
            try fileManager.createDirectory(at: swiftpm, withIntermediateDirectories: true)
        }
        try fixture("xcode-resolved-v3").write(to: swiftpm.appendingPathComponent("Package.resolved"))

        guard resolved else { return }
        let sourcePackages = derivedData.appendingPathComponent("SourcePackages")
        for name in ["combine-schedulers", "swift-clocks", "swift-concurrency-extras", "swift-dependencies",
                     "swift-issue-reporting"] {
            try fileManager.createDirectory(at: sourcePackages.appendingPathComponent("checkouts/\(name)"),
                                            withIntermediateDirectories: true)
        }
        let state = String(decoding: try fixture("xcode-workspace-state"), as: UTF8.self)
            .replacingOccurrences(of: "$PROJECT", with: folder.path)
        try Data(state.utf8).write(to: sourcePackages.appendingPathComponent("workspace-state.json"))
        let info: [String: Any] = ["WorkspacePath": project.path, "LastAccessedDate": Date()]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: derivedData.appendingPathComponent("info.plist"))
    }

    func remove() {
        try? FileManager.default.removeItem(at: folder)
    }
}

/// Manifests by package folder name, shaped like the real ones: they also declare packages
/// that only their tests use, and swift-syntax for macros, which Xcode didn't download here.
struct FakeManifests: ManifestReader {
    var byFolder: [String: Manifest] = [
        "swift-dependencies": .fake("swift-dependencies",
                                    uses: ["combine-schedulers", "swift-clocks", "swift-concurrency-extras",
                                           "swift-issue-reporting", "swift-syntax"],
                                    declaresAlso: ["swift-macro-testing", "swift-docc-plugin"]),
        "combine-schedulers": .fake("combine-schedulers", uses: ["swift-concurrency-extras", "swift-issue-reporting"],
                                    declaresAlso: ["opencombine"]),
        "swift-clocks": .fake("swift-clocks", uses: ["swift-concurrency-extras", "swift-issue-reporting"],
                              declaresAlso: ["swift-docc-plugin"]),
        "swift-concurrency-extras": .fake("swift-concurrency-extras", uses: [], declaresAlso: ["swift-docc-plugin"]),
        "swift-issue-reporting": .fake("swift-issue-reporting", uses: [], declaresAlso: ["swift-docc-plugin"]),
        "Feature": .fake("Feature", uses: ["swift-dependencies"]),
        "Settings": .fake("Settings", uses: ["feature", "logging"]),
        "Logging": .fake("Logging", uses: []),
        "Tools": .fake("Tools", uses: []),
    ]

    func manifest(ofPackageAt folder: URL) throws -> Manifest {
        guard let manifest = byFolder[folder.lastPathComponent] else { throw DepViewError.unreadableOutput }
        return manifest
    }
}

extension Manifest {
    /// One target using one product from each package in `uses`.
    static func fake(_ name: String, uses: [String], declaresAlso: [String] = []) -> Manifest {
        Manifest(name: name,
                 dependencies: (uses + declaresAlso).map { Dependency(identity: $0, traits: ["default"]) },
                 products: [name],
                 targets: [name],
                 uses: uses.map { TargetUse(use: .product(name: $0, package: $0), traits: []) },
                 traits: [:])
    }
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
