import Testing
@testable import DepViewCore

struct TreeRendererTests {
    /// Most tests leave out the counts line to focus on the tree.
    private let tree = TreeRenderer(showSummary: false)

    @Test func showsVersions() throws {
        let graph = try SPMLoader.parse(fixture("spm-tiny"))
        #expect(tree.render(graph) == """
            depview
            └── swift-argument-parser 1.8.2
            """)
    }

    @Test func foldsRepeatedPackage() throws {
        let graph = try SPMLoader.parse(fixture("spm-shared"))
        #expect(tree.render(graph) == """
            App
            ├── Networking
            │   └── Logging
            └── Analytics
                └── ↑ Logging
            """)
    }

    // y is drawn under x, so when the root reaches y it folds, even though
    // nothing was drawn yet when the root's children were first looked at.
    @Test func foldsPackageAnEarlierSiblingDrew() {
        let graph = makeGraph(root: "app", edges: ["app": ["x", "y"], "x": ["y"], "y": ["z"], "z": []])
        #expect(tree.render(graph) == """
            app
            ├── x
            │   └── y  +1
            │       └── z
            └── ↑ y
            """)
    }

    // Each brings in one package of its own; the "+1"s share a column.
    @Test func weightsLineUp() {
        let wide = makeGraph(root: "app", edges: ["app": ["long-name", "b"], "long-name": ["x"], "x": [], "b": ["c"], "c": []])
        #expect(tree.render(wide) == """
            app
            ├── long-name  +1
            │   └── x
            └── b          +1
                └── c
            """)
    }

    @Test func summaryCountsPackagesLevelsAndPins() {
        var graph = makeGraph(root: "app", edges: ["app": ["a", "b"], "a": [], "b": []])
        graph.nodes["a"] = DependencyNode(id: "a", name: "a", version: "main", url: nil, children: [], pin: .branch)
        graph.nodes["b"] = DependencyNode(id: "b", name: "b", version: "0687f71", url: nil, children: [], pin: .commit)
        #expect(TreeRenderer().render(graph) == """
            app  2 packages · 2 direct · 1 level · 1 on a branch · 1 on a commit
            ├── a branch main
            └── b commit 0687f71
            """)
    }

    @Test func summaryForNoDependencies() {
        #expect(TreeRenderer().render(makeGraph(root: "app", edges: ["app": []])) == "app  no dependencies")
    }

    @Test func mediumTree() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        try expectSnapshot(TreeRenderer().render(graph), named: "spm-medium.tree.txt")
    }

    @Test func mediumTreeAtDepthTwo() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        try expectSnapshot(TreeRenderer(maxDepth: 2).render(graph), named: "spm-medium.depth-2.tree.txt")
    }

    // ␛ stands in for the escape character, so the snapshot file is readable.
    @Test func mediumTreeInColor() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        let output = TreeRenderer(style: .ansi).render(graph).replacingOccurrences(of: "\u{1B}", with: "␛")
        try expectSnapshot(output, named: "spm-medium.color.tree.txt")
    }

    @Test func localPackagesAndPinsHaveTheirOwnColors() {
        var graph = makeGraph(root: "app", edges: ["app": ["feature", "kit"], "feature": [], "kit": []])
        graph.nodes["feature"] = DependencyNode(id: "feature", name: "Feature", version: nil,
                                                url: "/Users/dev/Projects/App/Packages/Feature", children: [])
        graph.nodes["kit"] = DependencyNode(id: "kit", name: "Kit", version: "main",
                                            url: "https://github.com/dev/kit", children: [], pin: .branch)
        let output = TreeRenderer(style: .ansi).render(graph)
        #expect(output.contains("\u{1B}[35mFeature\u{1B}[0m"))
        #expect(output.contains("Kit \u{1B}[33mbranch main\u{1B}[0m"))
    }

    @Test func plainStyleHasNoEscapeCodes() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        #expect(!TreeRenderer(style: .plain).render(graph).contains("\u{1B}"))
    }

    @Test func hidesVersions() throws {
        let graph = try SPMLoader.parse(fixture("spm-tiny"))
        #expect(TreeRenderer(showVersions: false, showSummary: false).render(graph) == """
            depview
            └── swift-argument-parser
            """)
    }

    @Test func depthOneShowsDirectDependenciesOnly() throws {
        let graph = try SPMLoader.parse(fixture("spm-shared"))
        #expect(TreeRenderer(maxDepth: 1, showSummary: false).render(graph) == """
            App
            ├── Networking
            └── Analytics
            """)
    }

    // A package first reached at the depth limit still shows its children
    // where it appears again higher up, instead of folding.
    @Test func packageCutOffByDepthIsExpandedLater() {
        let graph = makeGraph(root: "app", edges: [
            "app": ["feature", "core"],
            "feature": ["core"],
            "core": ["utils"],
            "utils": [],
        ])
        #expect(TreeRenderer(maxDepth: 2, showSummary: false).render(graph) == """
            app
            ├── feature
            │   └── core  +1
            └── core      +1
                └── utils
            """)
    }

    // Printing core again at the limit would add nothing, so it folds there.
    @Test func packageCutOffByDepthFoldsAtTheLimit() {
        let graph = makeGraph(root: "app", edges: [
            "app": ["a", "b"], "a": ["core"], "b": ["core"], "core": ["utils"], "utils": [],
        ])
        #expect(TreeRenderer(maxDepth: 2, showSummary: false).render(graph) == """
            app
            ├── a
            │   └── core  +1
            └── b
                └── ↑ core
            """)
    }

    @Test func cycleDoesNotHang() {
        let graph = makeGraph(root: "a", edges: ["a": ["b"], "b": ["a"]])
        #expect(tree.render(graph) == """
            a
            └── b
                └── ↑ a
            """)
    }
}
