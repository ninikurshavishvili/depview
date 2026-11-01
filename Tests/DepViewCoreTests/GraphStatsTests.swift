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

    @Test func rendersText() throws {
        let stats = GraphStats(graph: try SPMLoader.parse(fixture("spm-medium")))
        #expect(StatsRenderer.text(stats) == """
            Packages:     5  (1 direct, 4 transitive)
            Max depth:    3
            Most shared:  swift-concurrency-extras, swift-issue-reporting (each used by 3 packages)
            """)
    }

    @Test func rendersTextWithNothingShared() throws {
        let stats = GraphStats(graph: try SPMLoader.parse(fixture("spm-tiny")))
        #expect(StatsRenderer.text(stats).hasSuffix("Most shared:  none"))
    }

    @Test func rendersJSON() throws {
        let stats = GraphStats(graph: try SPMLoader.parse(fixture("spm-medium")))
        try expectSnapshot(StatsRenderer.json(stats), named: "spm-medium.stats.json")
    }
}
