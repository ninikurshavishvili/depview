import Foundation
import Testing
@testable import DepViewCore

struct XcodeLoaderTests {
    private func makeLoader(_ demo: DemoProject, manifests: FakeManifests = FakeManifests()) -> XcodeLoader {
        var loader = XcodeLoader()
        loader.derivedDataRoot = demo.derivedDataRoot
        loader.manifestReader = manifests
        return loader
    }

    @Test func resolvedProjectShowsTheWholeTree() throws {
        let demo = try DemoProject()
        defer { demo.remove() }
        let (graph, warnings) = try makeLoader(demo).loadWithWarnings(from: demo.project)
        #expect(warnings.isEmpty)
        try expectSnapshot(TreeRenderer().render(graph), named: "xcode-demo.tree.txt")
    }

    @Test func leavesOutPackagesXcodeNeverDownloaded() throws {
        let demo = try DemoProject()
        defer { demo.remove() }
        let graph = try makeLoader(demo).load(from: demo.project)
        #expect(Set(graph.nodes.keys) == [
            "demo.xcodeproj", "swift-dependencies", "combine-schedulers", "swift-clocks",
            "swift-concurrency-extras", "swift-issue-reporting", "feature", "settings", "logging",
        ])
    }

    // Logging is a package folder in the project, but only Settings uses it.
    @Test func packageFolderNoTargetLinksIsntADirectDependency() throws {
        let demo = try DemoProject()
        defer { demo.remove() }
        let graph = try makeLoader(demo).load(from: demo.project)
        #expect(graph.nodes[graph.rootID]?.children == ["swift-dependencies", "feature", "settings"])
        #expect(graph.nodes["settings"]?.children == ["feature", "logging"])
    }

    @Test func leavesOutPackagesTheAppDoesntReach() throws {
        let demo = try DemoProject()
        defer { demo.remove() }
        var manifests = FakeManifests()
        manifests.byFolder["Settings"] = .fake("Settings", uses: ["feature"])
        let graph = try makeLoader(demo, manifests: manifests).load(from: demo.project)
        #expect(graph.nodes["logging"] == nil)
        #expect(throws: DepViewError.self) {
            try WhyQuery().run("Logging", in: graph)
        }
    }

    @Test func versionsAndURLsComeFromPackageResolved() throws {
        let demo = try DemoProject()
        defer { demo.remove() }
        let graph = try makeLoader(demo).load(from: demo.project)
        #expect(graph.nodes["swift-clocks"]?.version == "1.1.1")
        #expect(graph.nodes["swift-clocks"]?.url == "https://github.com/pointfreeco/swift-clocks")
        #expect(graph.nodes["feature"]?.version == nil)
        #expect(graph.nodes["feature"]?.name == "Feature")
    }

    // Local packages are on disk already, so the links between them still show.
    @Test func unresolvedProjectShowsDirectDependencies() throws {
        let demo = try DemoProject(resolved: false)
        defer { demo.remove() }
        let (graph, warnings) = try makeLoader(demo).loadWithWarnings(from: demo.project)
        #expect(TreeRenderer().render(graph) == """
            Demo
            ├── swift-dependencies 1.17.2
            ├── Feature
            │   └── swift-dependencies 1.17.2 (seen above)
            └── Settings
                ├── Feature (seen above)
                └── Logging
            """)
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("Xcode hasn't downloaded Demo's packages yet") == true)
    }

    @Test func derivedDataFolderCanBeGiven() throws {
        let demo = try DemoProject()
        defer { demo.remove() }
        var loader = makeLoader(demo)
        loader.derivedDataRoot = demo.folder.appendingPathComponent("nowhere")
        loader.derivedData = demo.derivedData
        #expect(try loader.load(from: demo.project).nodes.count == 9)
    }

    @Test func givenFolderWithoutPackagesThrows() throws {
        let demo = try DemoProject()
        defer { demo.remove() }
        var loader = makeLoader(demo)
        loader.derivedData = demo.folder
        #expect(throws: DepViewError.derivedDataNotFound(path: demo.folder.path)) {
            try loader.load(from: demo.project)
        }
    }

    @Test func unreadableManifestIsAWarning() throws {
        let demo = try DemoProject()
        defer { demo.remove() }
        var manifests = FakeManifests()
        manifests.byFolder["swift-clocks"] = nil
        let (graph, warnings) = try makeLoader(demo, manifests: manifests).loadWithWarnings(from: demo.project)
        #expect(warnings == ["Couldn't read swift-clocks's Package.swift, so its dependencies aren't shown."])
        #expect(graph.nodes["swift-clocks"]?.children == [])
    }

    // The workspace's own Tools package comes after the project's packages.
    @Test func cocoaPodsWorkspaceShowsItsPackages() throws {
        let demo = try DemoProject(workspace: true)
        defer { demo.remove() }
        let (graph, warnings) = try makeLoader(demo).loadWithWarnings(from: demo.project)
        #expect(graph.rootID == "demo.xcworkspace")
        #expect(graph.nodes[graph.rootID]?.children == ["swift-dependencies", "feature", "settings", "tools"])
        #expect(graph.nodes.count == 10)
        #expect(graph.nodes["swift-dependencies"]?.version == "1.17.2")
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("CocoaPods") == true)
    }
}
