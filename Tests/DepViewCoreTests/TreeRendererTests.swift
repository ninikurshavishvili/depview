import Testing
@testable import DepViewCore

struct TreeRendererTests {
    @Test func showsVersions() throws {
        let graph = try SPMLoader.parse(fixture("spm-tiny"))
        #expect(TreeRenderer().render(graph) == """
            depview
            └── swift-argument-parser 1.8.2
            """)
    }

    @Test func marksRepeatedPackage() throws {
        let graph = try SPMLoader.parse(fixture("spm-shared"))
        #expect(TreeRenderer().render(graph) == """
            App
            ├── Networking
            │   └── Logging
            └── Analytics
                └── Logging (seen above)
            """)
    }

    @Test func depthOneShowsDirectDependenciesOnly() throws {
        let graph = try SPMLoader.parse(fixture("spm-shared"))
        #expect(TreeRenderer(maxDepth: 1).render(graph) == """
            App
            ├── Networking
            └── Analytics
            """)
    }

    // A package first reached at the depth limit still shows its children
    // where it appears again higher up, instead of "(seen above)".
    @Test func packageCutOffByDepthIsExpandedLater() {
        let graph = makeGraph(root: "app", edges: [
            "app": ["feature", "core"],
            "feature": ["core"],
            "core": ["utils"],
            "utils": [],
        ])
        #expect(TreeRenderer(maxDepth: 2).render(graph) == """
            app
            ├── feature
            │   └── core
            └── core
                └── utils
            """)
    }

    @Test func cycleDoesNotHang() {
        let graph = makeGraph(root: "a", edges: ["a": ["b"], "b": ["a"]])
        #expect(TreeRenderer().render(graph) == """
            a
            └── b
                └── a (seen above)
            """)
    }
}
