import Testing
@testable import DepViewCore

struct WhyTests {
    private func lines(_ result: WhyResult) -> [String] {
        result.paths.map { $0.map(\.name).joined(separator: " → ") }
    }

    /// root → 5 layers of two packages, each linked to both in the next layer → target.
    /// That's 2^5 = 32 paths from root to target.
    private func lattice() -> DependencyGraph {
        var edges: [String: [String]] = ["root": ["x1", "y1"], "target": []]
        for layer in 1...5 {
            let next = layer < 5 ? ["x\(layer + 1)", "y\(layer + 1)"] : ["target"]
            edges["x\(layer)"] = next
            edges["y\(layer)"] = next
        }
        return makeGraph(root: "root", edges: edges)
    }

    @Test func directDependencyHasOnePath() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        let result = try WhyQuery().run("swift-dependencies", in: graph)
        #expect(lines(result) == ["Medium → swift-dependencies"])
        #expect(result.totalPaths == 1)
    }

    @Test func sharedPackageListsEveryPathShortestFirst() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        let result = try WhyQuery().run("swift-issue-reporting", in: graph)
        #expect(lines(result) == [
            "Medium → swift-dependencies → swift-issue-reporting",
            "Medium → swift-dependencies → combine-schedulers → swift-issue-reporting",
            "Medium → swift-dependencies → swift-clocks → swift-issue-reporting",
        ])
        #expect(result.totalPaths == 3)
    }

    @Test func matchesNameIgnoringCase() throws {
        let graph = try SPMLoader.parse(fixture("spm-shared"))
        let result = try WhyQuery().run("LOGGING", in: graph)
        #expect(result.package.id == "logging")
        #expect(lines(result) == ["App → Networking → Logging", "App → Analytics → Logging"])
    }

    @Test func rootPackage() throws {
        let graph = try SPMLoader.parse(fixture("spm-shared"))
        let result = try WhyQuery().run("app", in: graph)
        #expect(result.isRoot)
        #expect(WhyRenderer().render(result) == "App is the root package, so nothing pulls it in.")
    }

    @Test func unknownPackageSuggestsCloseNames() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        #expect(throws: DepViewError.packageNotFound(name: "swift-clock", suggestions: ["swift-clocks"])) {
            try WhyQuery().run("swift-clock", in: graph)
        }
    }

    @Test func unknownPackageWithNothingClose() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        #expect(throws: DepViewError.packageNotFound(name: "alamofire", suggestions: [])) {
            try WhyQuery().run("alamofire", in: graph)
        }
    }

    @Test func cycleDoesNotHang() throws {
        let graph = makeGraph(root: "a", edges: ["a": ["b"], "b": ["a"]])
        let result = try WhyQuery().run("b", in: graph)
        #expect(lines(result) == ["a → b"])
    }

    @Test func longListIsCutOffButCounted() throws {
        let result = try WhyQuery(limit: 20).run("target", in: lattice())
        #expect(result.paths.count == 20)
        #expect(result.totalPaths == 32)
        #expect(Set(lines(result)).count == 20)
    }

    @Test func noLimitListsEveryPath() throws {
        let result = try WhyQuery(limit: nil).run("target", in: lattice())
        #expect(result.paths.count == 32)
        #expect(result.totalPaths == 32)
    }

    @Test func rendersPaths() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        let result = try WhyQuery().run("swift-concurrency-extras", in: graph)
        try expectSnapshot(WhyRenderer().render(result), named: "spm-medium.why.txt")
    }

    @Test func rendersHowManyPathsAreHidden() throws {
        let output = WhyRenderer().render(try WhyQuery(limit: 20).run("target", in: lattice()))
        let lines = output.split(separator: "\n")
        #expect(lines.first == "target is pulled in by 32 paths:")
        #expect(lines.last == "  …and 12 more. Pass --all to list them.")
        #expect(lines.count == 22)
    }

    @Test func singlePathIsSingular() throws {
        let graph = try SPMLoader.parse(fixture("spm-tiny"))
        let output = WhyRenderer().render(try WhyQuery().run("swift-argument-parser", in: graph))
        #expect(output == """
            swift-argument-parser 1.8.2 is pulled in by 1 path:
              depview → swift-argument-parser
            """)
    }
}
