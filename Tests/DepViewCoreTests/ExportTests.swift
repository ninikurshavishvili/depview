import Foundation
import Testing
@testable import DepViewCore

struct ExportTests {
    @Test func mermaidUsesShortIDsAndOneLinePerEdge() throws {
        let graph = try SPMLoader.parse(fixture("spm-shared"))
        #expect(MermaidRenderer().render(graph) == """
            graph TD
                n0["App"]
                n1["Networking"]
                n2["Logging"]
                n3["Analytics"]
                n0 --> n1
                n0 --> n3
                n1 --> n2
                n3 --> n2
            """)
    }

    @Test func mermaidMedium() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        try expectSnapshot(MermaidRenderer().render(graph), named: "spm-medium.mmd")
    }

    @Test func dotMedium() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        try expectSnapshot(DotRenderer().render(graph), named: "spm-medium.dot")
    }

    @Test func jsonMedium() throws {
        let graph = try SPMLoader.parse(fixture("spm-medium"))
        try expectSnapshot(JSONRenderer().render(graph), named: "spm-medium.export.json")
    }

    @Test func quotesInNamesAreEscaped() {
        let graph = makeGraph(root: "app", edges: ["app": [#"say"hi"#], #"say"hi"#: []])
        #expect(MermaidRenderer().render(graph).contains(#"n1["say#quot;hi"]"#))
        #expect(DotRenderer().render(graph).contains(#""app" -> "say\"hi";"#))
    }

    @Test func jsonHasEveryKeyForEveryPackage() throws {
        let graph = try SPMLoader.parse(fixture("spm-tiny"))
        let data = Data(try JSONRenderer().render(graph).utf8)
        let document = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(document["schemaVersion"] as? Int == 1)
        #expect(document["root"] as? String == "depview")

        let packages = try #require(document["packages"] as? [[String: Any]])
        #expect(packages.map { $0["id"] as? String } == ["depview", "swift-argument-parser"])
        #expect(packages[0]["version"] is NSNull)
        #expect(packages[1]["version"] as? String == "1.8.2")
        #expect(packages[0]["dependencies"] as? [String] == ["swift-argument-parser"])
    }
}
