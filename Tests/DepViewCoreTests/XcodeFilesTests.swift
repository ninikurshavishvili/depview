import Foundation
import Testing
@testable import DepViewCore

/// The readers for each file the Xcode loader uses.
struct XcodeFilesTests {
    // Package references first, then package folders in the navigator. The Assets folder
    // and the built app aren't packages.
    @Test func readsPackageReferencesInOrder() throws {
        let demo = try DemoProject(resolved: false)
        defer { demo.remove() }
        let references = try XcodeProjectFile.packageReferences(in: demo.project)
        #expect(references.map(\.identity) == ["swift-dependencies", "feature", "settings", "logging"])
        #expect(references.map(\.name) == ["swift-dependencies", "Feature", "Settings", "Logging"])
        #expect(references.map(\.isFolderEntry) == [false, false, true, true])
        #expect(references[0].source == .remote(url: "https://github.com/pointfreeco/swift-dependencies"))
        // Settings' path is relative to its group, Packages.
        let folders = references.compactMap { reference -> String? in
            guard case .local(let folder) = reference.source else { return nil }
            return folder.path
        }
        #expect(folders == [
            demo.folder.appendingPathComponent("Packages/Feature").path,
            demo.folder.appendingPathComponent("Packages/Settings").path,
            demo.folder.appendingPathComponent("Packages/Logging").path,
        ])
    }

    // Dependencies comes from a package reference, so it names its package and isn't listed.
    @Test func readsProductsLinkedFromPackageFolders() throws {
        let demo = try DemoProject(resolved: false)
        defer { demo.remove() }
        #expect(try XcodeProjectFile.linkedProducts(in: demo.project) == ["Settings", "Tools", "LintPlugin"])
    }

    @Test func unreadableProjectThrows() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let project = folder.appendingPathComponent("Broken.xcodeproj")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try Data("{ objects = ".utf8).write(to: project.appendingPathComponent("project.pbxproj"))
        #expect(throws: DepViewError.unreadableProject(path: project.path)) {
            try XcodeProjectFile.packageReferences(in: project)
        }
    }

    @Test func readsWorkspaceProjectsAndPackageFolders() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let workspace = folder.appendingPathComponent("App.xcworkspace")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        for name in ["Modules", "Docs"] {
            try FileManager.default.createDirectory(at: folder.appendingPathComponent(name),
                                                    withIntermediateDirectories: true)
        }
        try Data().write(to: folder.appendingPathComponent("Modules/Package.swift"))
        try Data("""
            <Workspace version = "1.0">
               <FileRef location = "group:App.xcodeproj"></FileRef>
               <FileRef location = "group:Pods/Pods.xcodeproj"></FileRef>
               <FileRef location = "absolute:/Users/dev/Shared/Shared.xcodeproj"></FileRef>
               <FileRef location = "group:Modules"></FileRef>
               <FileRef location = "group:Docs"></FileRef>
               <FileRef location = "group:README.md"></FileRef>
            </Workspace>
            """.utf8).write(to: workspace.appendingPathComponent("contents.xcworkspacedata"))
        #expect(try XcodeProjectFile.projects(inWorkspace: workspace).map(\.path) == [
            folder.appendingPathComponent("App.xcodeproj").path,
            folder.appendingPathComponent("Pods/Pods.xcodeproj").path,
            "/Users/dev/Shared/Shared.xcodeproj",
        ])
        // Docs has no Package.swift, so it's just a folder.
        #expect(try XcodeProjectFile.packageFolders(inWorkspace: workspace).map(\.path) == [
            folder.appendingPathComponent("Modules").path,
        ])
    }

    @Test(arguments: [
        ("https://github.com/apple/swift-nio.git", "swift-nio"),
        ("https://github.com/Alamofire/Alamofire.git", "alamofire"),
        ("git@github.com:pointfreeco/swift-clocks.git", "swift-clocks"),
        ("https://github.com/apple/swift-collections/", "swift-collections"),
        ("/Users/dev/Projects/App/Packages/Feature", "feature"),
    ])
    func packageIdentityMatchesSwiftPM(_ location: String, _ identity: String) {
        #expect(packageIdentity(for: location) == identity)
    }

    @Test func readsResolvedVersion3() throws {
        let pins = try #require(PackageResolved.pins(from: fixture("xcode-resolved-v3")))
        #expect(pins.count == 5)
        #expect(pins.first == PackagePin(identity: "combine-schedulers",
                                         location: "https://github.com/pointfreeco/combine-schedulers",
                                         version: "1.2.2"))
    }

    // A branch pin shows the branch, and a commit pin a short hash.
    @Test func readsResolvedVersion2WithBranchAndCommitPins() throws {
        let pins = try #require(PackageResolved.pins(from: fixture("xcode-resolved-v2")))
        #expect(pins.map(\.identity) == ["swift-collections", "swift-dependencies", "swift-syntax"])
        #expect(pins.map(\.version) == ["main", "1.17.2", "0687f71"])
    }

    @Test func readsResolvedVersion1() throws {
        let pins = try #require(PackageResolved.pins(from: fixture("xcode-resolved-v1")))
        #expect(pins.map(\.identity) == ["combine-schedulers", "swift-dependencies"])
        #expect(pins.map(\.version) == ["1.2.2", "1.17.2"])
    }

    @Test(arguments: ["{", #"{"version": 3}"#, "[]"])
    func rejectsBrokenResolvedFile(_ text: String) {
        #expect(PackageResolved.pins(from: Data(text.utf8)) == nil)
    }

    @Test func readsWorkspaceState() throws {
        let demo = try DemoProject()
        defer { demo.remove() }
        let sourcePackages = demo.derivedData.appendingPathComponent("SourcePackages")
        let packages = try #require(DerivedData.packages(inSourcePackages: sourcePackages))
        #expect(packages.count == 6)

        let clocks = try #require(packages.first { $0.identity == "swift-clocks" })
        #expect(clocks.folder.path == sourcePackages.appendingPathComponent("checkouts/swift-clocks").path)
        #expect(clocks.location == "https://github.com/pointfreeco/swift-clocks")

        let feature = try #require(packages.first { $0.identity == "feature" })
        #expect(feature.name == "Feature")
        #expect(feature.folder.path == demo.folder.appendingPathComponent("Packages/Feature").path)
    }

    // A moved project leaves its old DerivedData folder behind, so the path inside decides.
    @Test func findsTheNewestDerivedDataFolderForTheProject() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let project = folder.appendingPathComponent("App.xcodeproj")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let root = folder.appendingPathComponent("DerivedData")
        func addFolder(_ name: String, workspace: String, lastUsed: TimeInterval) throws {
            let derivedData = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
            let info: [String: Any] = ["WorkspacePath": workspace, "LastAccessedDate": Date(timeIntervalSince1970: lastUsed)]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
                .write(to: derivedData.appendingPathComponent("info.plist"))
        }
        try addFolder("App-older", workspace: project.path, lastUsed: 100)
        try addFolder("App-newer", workspace: project.path, lastUsed: 200)
        try addFolder("App-moved", workspace: "/Users/dev/Documents/App.xcodeproj", lastUsed: 300)

        #expect(DerivedData.folder(for: project, in: root)?.lastPathComponent == "App-newer")
        #expect(DerivedData.folder(for: folder.appendingPathComponent("Other.xcodeproj"), in: root) == nil)
    }

    // Checked against folder names Xcode made.
    @Test(arguments: [
        ("/Users/dev/Projects/App/App.xcodeproj", "hdmwlhqlhzrvbsaljpjnnenmomcd"),
        ("/Users/dev/Projects/My App/My App.xcworkspace", "ebbimwxuiukctxcestopiyjxgexa"),
    ])
    func folderHashMatchesXcode(_ path: String, _ hash: String) {
        #expect(DerivedData.folderHash(for: path) == hash)
    }

    // xcodebuild -resolvePackageDependencies makes the folder without an info.plist.
    @Test func findsAFolderWithoutInfoPlistByItsHash() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let project = folder.appendingPathComponent("App.xcodeproj")
        let root = folder.appendingPathComponent("DerivedData")
        for name in ["App-\(DerivedData.folderHash(for: project.path))", "App-otherhash"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name),
                                                    withIntermediateDirectories: true)
        }
        #expect(DerivedData.folder(for: project, in: root)?.lastPathComponent
                == "App-\(DerivedData.folderHash(for: project.path))")
    }

    // swift-clocks declares swift-docc-plugin, but none of its targets use it.
    @Test func readsRealDumpPackageOutput() throws {
        let manifest = try DumpPackageReader.parse(fixture("xcode-dump-package"))
        #expect(manifest.name == "swift-clocks")
        #expect(manifest.dependencies.map(\.identity) == [
            "swift-docc-plugin", "swift-concurrency-extras", "swift-issue-reporting",
        ])
        #expect(manifest.usedPackages(traitsOn: ["default"], manifests: [:]) == [
            "swift-concurrency-extras", "swift-issue-reporting",
        ])
    }

    private let navigationManifest = #"""
        {
          "name": "Navigation",
          "dependencies": [
            {"sourceControl": [{"identity": "swift-sharing", "traits": [{"name": "default"}]}]},
            {"sourceControl": [{"identity": "swift-case-paths",
                                "traits": [{"name": "default"}, {"name": "Extra", "condition": {"traits": ["Fancy"]}}]}]},
            {"sourceControl": [{"identity": "swift-testing", "traits": [{"name": "default"}]}]},
            {"fileSystem": [{"identity": "local-kit", "path": "/Users/dev/LocalKit"}]}
          ],
          "products": [{"name": "Navigation"}],
          "targets": [
            {"name": "Navigation", "type": "regular", "dependencies": [
              {"product": ["Sharing", "swift-sharing", null, {"platformNames": [], "traits": ["Sharing"]}]},
              {"product": ["CasePaths", "swift-case-paths", null, null]},
              {"byName": ["NavigationCore", null]},
              {"byName": ["LocalKit", null]}
            ]},
            {"name": "NavigationCore", "type": "regular", "dependencies": []},
            {"name": "NavigationTests", "type": "test", "dependencies": [
              {"product": ["Testing", "swift-testing", null, null]}
            ]}
          ],
          "traits": [{"name": "default", "enabledTraits": []}, {"name": "Sharing", "enabledTraits": []}]
        }
        """#

    @Test func readsTraitsAndTargetUses() throws {
        let manifest = try DumpPackageReader.parse(Data(navigationManifest.utf8))
        #expect(manifest.dependencies.map(\.identity) == ["swift-sharing", "swift-case-paths", "swift-testing", "local-kit"])
        // A trait asked for only under a condition isn't counted, and no "traits" key means defaults.
        #expect(manifest.dependencies.map(\.traits) == [["default"], ["default"], ["default"], ["default"]])
        #expect(manifest.uses.count == 4)
        #expect(manifest.traits == ["default": [], "Sharing": []])
    }

    // Test targets don't count, a trait-gated product counts only with its trait on, and a bare
    // name is either a target in the package or a product of a dependency.
    @Test func usesOnlyWhatTargetsReallyNeed() throws {
        let manifest = try DumpPackageReader.parse(Data(navigationManifest.utf8))
        let localKit = Manifest.fake("LocalKit", uses: [])
        #expect(manifest.usedPackages(traitsOn: manifest.expand(["default"]), manifests: ["local-kit": localKit])
                == ["swift-case-paths", "local-kit"])
        #expect(manifest.usedPackages(traitsOn: manifest.expand(["default", "Sharing"]), manifests: ["local-kit": localKit])
                == ["swift-sharing", "swift-case-paths", "local-kit"])
    }

    @Test func productCanNameThePackageInsteadOfItsIdentity() {
        var manifest = Manifest.fake("App", uses: [])
        manifest.dependencies = [Manifest.Dependency(identity: "alamofire", traits: ["default"])]
        manifest.uses = [Manifest.TargetUse(use: .product(name: "Alamofire", package: "Alamofire"), traits: [])]
        #expect(manifest.usedPackages(traitsOn: [], manifests: [:]) == ["alamofire"])
    }

    @Test func traitsTurnOnOtherTraits() {
        var manifest = Manifest.fake("Kit", uses: [])
        manifest.traits = ["default": ["A"], "A": ["B"], "B": [], "C": []]
        #expect(manifest.expand(["default"]) == ["default", "A", "B"])
    }
}
