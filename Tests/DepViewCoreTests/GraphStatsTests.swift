import Testing
@testable import DepViewCore

struct GraphStatsTests {
    @Test func tinyPackage() throws {
        let stats = GraphStats(graph: try SPMLoader.parse(fixture("spm-tiny")))
        #expect(stats.packages == 1)
        #expect(stats.direct == 1)
        #expect(stats.transitive == 0)
        #expect(stats.maxDepth == 1)
        #expect(stats.mostShared == nil)
    }

    @Test func sharedPackage() throws {
        let stats = GraphStats(graph: try SPMLoader.parse(fixture("spm-shared")))
        #expect(stats.packages == 3)
        #expect(stats.direct == 2)
        #expect(stats.transitive == 1)
        #expect(stats.maxDepth == 2)
        #expect(stats.mostShared == GraphStats.MostShared(packages: ["Logging"], usedBy: 2))
    }

    @Test func mediumPackageWithATie() throws {
        let stats = GraphStats(graph: try SPMLoader.parse(fixture("spm-medium")))
        #expect(stats.packages == 5)
        #expect(stats.direct == 1)
        #expect(stats.transitive == 4)
        #expect(stats.maxDepth == 3)
        #expect(stats.mostShared == GraphStats.MostShared(
            packages: ["swift-concurrency-extras", "swift-issue-reporting"], usedBy: 3
        ))
    }

    @Test func packageWithNoDependencies() {
        let stats = GraphStats(graph: makeGraph(root: "a", edges: ["a": []]))
        #expect(stats.packages == 0)
        #expect(stats.maxDepth == 0)
        #expect(stats.mostShared == nil)
    }

    @Test func cycleDoesNotHang() {
        let stats = GraphStats(graph: makeGraph(root: "a", edges: ["a": ["b"], "b": ["a"]]))
        #expect(stats.packages == 1)
    }

    // A project with a local module, a branch pin, a commit pin and licenses.
    private func app() -> DependencyGraph {
        var graph = makeGraph(root: "app", edges: [
            "app": ["feature", "kit", "net"], "feature": ["util"], "kit": [], "net": [], "util": [],
        ])
        func node(_ id: String, _ name: String, version: String? = nil, url: String, pin: Pin? = nil,
                  license: String? = nil) -> DependencyNode {
            DependencyNode(id: id, name: name, version: version, url: url, children: graph.nodes[id]?.children ?? [],
                           pin: pin, license: license)
        }
        graph.nodes["feature"] = node("feature", "Feature", url: "/Users/dev/Projects/App/Packages/Feature")
        graph.nodes["kit"] = node("kit", "Kit", version: "main", url: "https://github.com/dev/kit", pin: .branch, license: "MIT")
        graph.nodes["net"] = node("net", "Net", version: "0687f71", url: "https://github.com/dev/net", pin: .commit)
        graph.nodes["util"] = node("util", "Util", version: "1.0.0", url: "https://github.com/dev/util", pin: .release,
                                   license: "Apache-2.0")
        return graph
    }

    @Test func countsLocalPackagesLicensesAndPins() {
        let stats = GraphStats(graph: app())
        #expect(stats.project == "app")
        #expect(stats.local == 1)
        #expect(stats.downloaded == 3)
        #expect(stats.licenses == ["MIT": 1, "Apache-2.0": 1, "unknown": 1])
        #expect(stats.onBranch == [GraphStats.Pinned(package: "Kit", version: "main")])
        #expect(stats.onCommit == [GraphStats.Pinned(package: "Net", version: "0687f71")])
        #expect(stats.heaviest == [GraphStats.Weight(package: "Feature", bringsIn: 1)])
    }

    @Test func rendersText() {
        #expect(StatsRenderer.text(GraphStats(graph: app())) == """
            app
            Packages      4: 3 direct, 1 through other packages
            From          1 local, 3 downloaded
            Max depth     2
            Most shared   none
            Licenses      Apache-2.0 1, MIT 1, unknown 1

            Heaviest direct dependencies, by packages only they bring in
              Feature  ████████████████████ 1

            Watch out
              Kit follows branch main, not a release.
              Net is pinned to commit 0687f71, not a release.
            """)
    }

    @Test func rendersMediumPackage() throws {
        let stats = GraphStats(graph: try SPMLoader.parse(fixture("spm-medium")))
        #expect(StatsRenderer.text(stats) == """
            Medium
            Packages      5: 1 direct, 4 through other packages
            From          5 downloaded
            Max depth     3
            Most shared   swift-concurrency-extras, swift-issue-reporting, each used by 3 packages
            Licenses      unknown 5

            Heaviest direct dependencies, by packages only they bring in
              swift-dependencies  ████████████████████ 4
            """)
    }

    @Test func rendersTextWithNothingShared() throws {
        let stats = GraphStats(graph: try SPMLoader.parse(fixture("spm-tiny")))
        #expect(StatsRenderer.text(stats).contains("Packages      1: all direct\n"))
        #expect(StatsRenderer.text(stats).contains("Most shared   none\n"))
    }

    @Test func rendersNoDependencies() {
        #expect(StatsRenderer.text(GraphStats(graph: makeGraph(root: "a", edges: ["a": []]))) == "a\nNo dependencies.")
    }

    @Test func rendersJSON() throws {
        let stats = GraphStats(graph: try SPMLoader.parse(fixture("spm-medium")))
        try expectSnapshot(StatsRenderer.json(stats), named: "spm-medium.stats.json")
    }
}
