import Foundation
import Testing
@testable import DepViewCore

struct SPMLoaderTests {
    @Test func parsesTinyPackage() throws {
        let graph = try SPMLoader.parse(fixture("spm-tiny"))
        #expect(graph.rootID == "depview")
        #expect(graph.nodes.count == 2)

        let root = try #require(graph.nodes["depview"])
        #expect(root.version == nil)
        #expect(root.children == ["swift-argument-parser"])

        let parser = try #require(graph.nodes["swift-argument-parser"])
        #expect(parser.version == "1.8.2")
        #expect(parser.url == "https://github.com/apple/swift-argument-parser")
        #expect(parser.children.isEmpty)
    }

    @Test func sharedDependencyBecomesOneNode() throws {
        let graph = try SPMLoader.parse(fixture("spm-shared"))
        #expect(graph.nodes.count == 4)
        #expect(graph.nodes["app"]?.children == ["networking", "analytics"])
        #expect(graph.nodes["networking"]?.children == ["logging"])
        #expect(graph.nodes["analytics"]?.children == ["logging"])
    }

    @Test func parsesMediumPackage() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        #expect(graph.rootID == "medium")
        // The JSON has 10 entries, because shared packages repeat under each parent.
        #expect(graph.nodes.count == 6)

        let dependencies = try #require(graph.nodes["swift-dependencies"])
        #expect(dependencies.version == "1.17.2")
        #expect(dependencies.url == "https://github.com/pointfreeco/swift-dependencies")
        #expect(dependencies.children == [
            "combine-schedulers", "swift-clocks", "swift-concurrency-extras", "swift-issue-reporting",
        ])

        #expect(graph.nodes["swift-clocks"]?.version == "1.1.1")
        #expect(graph.nodes["combine-schedulers"]?.url == "https://github.com/pointfreeco/combine-schedulers")
    }

    // Each of these is listed three times in the JSON, once under each package
    // that uses it, but becomes one node with all three as parents.
    @Test(arguments: ["swift-concurrency-extras", "swift-issue-reporting"])
    func mediumSharedPackageIsOneNode(_ id: String) throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        let parents = graph.nodes.values.filter { $0.children.contains(id) }.map(\.id)
        #expect(parents.sorted() == ["combine-schedulers", "swift-clocks", "swift-dependencies"])
        #expect(graph.nodes[id]?.children == [])
    }

    @Test func skipsProgressLinesBeforeJSON() throws {
        let output = Data("Fetching https://github.com/apple/swift-argument-parser\n".utf8) + (try fixture("spm-tiny"))
        #expect(try SPMLoader.parse(output).nodes.count == 2)
    }

    @Test(arguments: ["", "not json", #"{"identity": "broken"}"#])
    func rejectsUnreadableOutput(_ output: String) {
        #expect(throws: DepViewError.unreadableOutput) {
            try SPMLoader.parse(Data(output.utf8))
        }
    }

    @Test func missingFolder() {
        let folder = URL(fileURLWithPath: "/no/such/folder")
        #expect(throws: DepViewError.folderNotFound(path: folder.path)) {
            try SPMLoader().load(from: folder)
        }
    }

    @Test func folderWithoutManifest() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(throws: DepViewError.noPackageManifest(path: folder.path)) {
            try SPMLoader().load(from: folder)
        }
    }
}
