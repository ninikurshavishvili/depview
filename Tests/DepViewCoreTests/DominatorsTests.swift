import Testing
@testable import DepViewCore

struct DominatorsTests {
    // app → a → c, app → b → c, c → d: both ways to d pass c.
    private let diamond = makeGraph(root: "app", edges: [
        "app": ["a", "b"], "a": ["c"], "b": ["c"], "c": ["d"], "d": [],
    ])

    @Test func everyPathGoesThroughTheJoin() {
        let dominators = Dominators(diamond)
        #expect(dominators.through("d") == ["c"])
        #expect(dominators.through("c") == [])
        #expect(dominators.through("a") == [])
    }

    @Test func countsPackagesOnlyThroughEach() {
        let dominators = Dominators(diamond)
        #expect(dominators.onlyThrough("c") == 1)
        #expect(dominators.onlyThrough("a") == 0)
        #expect(dominators.onlyThrough("app") == 4)
    }

    @Test func chainListsEveryStepNearestTheRootFirst() {
        let dominators = Dominators(makeGraph(root: "app", edges: ["app": ["a"], "a": ["b"], "b": ["c"], "c": []]))
        #expect(dominators.through("c") == ["a", "b"])
        #expect(dominators.onlyThrough("a") == 2)
    }

    @Test func mediumPackage() throws {
        let dominators = Dominators(try SPMLoader.parse(fixture("spm-medium")))
        #expect(dominators.through("swift-clocks") == ["swift-dependencies"])
        #expect(dominators.onlyThrough("swift-dependencies") == 4)
        #expect(dominators.onlyThrough("combine-schedulers") == 0)
    }

    @Test func cycleDoesNotHang() {
        let dominators = Dominators(makeGraph(root: "a", edges: ["a": ["b"], "b": ["c", "a"], "c": []]))
        #expect(dominators.through("c") == ["b"])
        #expect(dominators.onlyThrough("b") == 1)
    }

    @Test func unknownPackageHasNothing() {
        let dominators = Dominators(diamond)
        #expect(dominators.through("nope") == [])
        #expect(dominators.onlyThrough("nope") == 0)
    }
}
