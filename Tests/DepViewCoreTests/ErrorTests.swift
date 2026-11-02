import Testing
@testable import DepViewCore

struct ErrorTests {
    /// One of each error.
    static let everyError: [DepViewError] = [
        .folderNotFound(path: "/Users/dev/Projects/App"),
        .noPackageManifest(path: "/Users/dev/Projects/App"),
        .swiftNotFound,
        .swiftCommandFailed(output: "error: 'app': Invalid manifest"),
        .unreadableOutput,
        .packageNotFound(name: "swift-clock", suggestions: ["swift-clocks"]),
        .packageNotFound(name: "nothing-like-it", suggestions: []),
        .cannotWriteFile(path: "/Users/dev/Projects/App/deps.mmd"),
        .noProject(path: "/Users/dev/Projects/App"),
        .severalProjects(path: "/Users/dev/Projects/App", names: ["App.xcodeproj", "Tools.xcodeproj"]),
        .unreadableProject(path: "/Users/dev/Projects/App/App.xcodeproj"),
        .derivedDataNotFound(path: "/Users/dev/Build"),
    ]

    // `hint` isn't optional, so every case has one; this checks none is empty.
    @Test(arguments: everyError)
    func printsAMessageAndAHint(_ error: DepViewError) {
        #expect(!error.message.isEmpty)
        #expect(!error.hint.isEmpty)
        #expect(error.errorDescription == "\(error.message)\nHint: \(error.hint)")
    }

    @Test func toolErrorsExitWith2AndTheRestWith1() {
        #expect(Self.everyError.filter { $0.exitCode == 2 } == [
            .swiftNotFound, .swiftCommandFailed(output: "error: 'app': Invalid manifest"), .unreadableOutput,
        ])
        #expect(Self.everyError.allSatisfy { $0.exitCode == 1 || $0.exitCode == 2 })
    }

    @Test func severalProjectsSuggestsTheFirst() {
        let error = DepViewError.severalProjects(path: "/Users/dev/Projects/App", names: ["App.xcodeproj", "Tools.xcodeproj"])
        #expect(error.message == "/Users/dev/Projects/App has several Xcode projects: App.xcodeproj, Tools.xcodeproj.")
        #expect(error.hint == "Pass the one you want, e.g. /Users/dev/Projects/App/App.xcodeproj")
    }

    // Real output for a typo in Package.swift, with shorter paths. The first line is mostly
    // the compiler command, and the excerpt repeats the error.
    @Test func keepsJustSwiftPMsErrorLines() {
        let output = """
            error: 'typo': Invalid manifest (compiled with: ["/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc", "-vfsoverlay", "/var/folders/xy/T/vfs.yaml", "-swift-version", "6", "/Users/dev/Projects/Typo/Package.swift", "-o", "/var/folders/xy/T/typo-manifest"])
            /Users/dev/Projects/Typo/Package.swift:6:21: error: type 'Array<Package.Dependency>.ArrayLiteralElement' (aka 'Package.Dependency') has no member 'packge'
            4 | let package = Package(
            5 |     name: "Typo",
            6 |     dependencies: [.packge(path: "../Lib")]
              |                     `- error: type 'Array<Package.Dependency>.ArrayLiteralElement' (aka 'Package.Dependency') has no member 'packge'
            7 | )
            8 |
            """
        #expect(SwiftCLI.errorLines(in: output) == """
            error: 'typo': Invalid manifest
            /Users/dev/Projects/Typo/Package.swift:6:21: error: type 'Array<Package.Dependency>.ArrayLiteralElement' (aka 'Package.Dependency') has no member 'packge'
            """)
    }

    @Test func leavesOutWarnings() {
        let output = """
            error: the package at '/Users/dev/Projects/NoSuchLib' cannot be accessed (/Users/dev/Projects/NoSuchLib doesn't exist in file system)
            warning: 'missing': Source files for target Missing should be located under 'Sources/Missing'
            """
        #expect(SwiftCLI.errorLines(in: output)
                == "error: the package at '/Users/dev/Projects/NoSuchLib' cannot be accessed (/Users/dev/Projects/NoSuchLib doesn't exist in file system)")
    }

    @Test func keepsEverythingWithoutAnErrorLine() {
        #expect(SwiftCLI.errorLines(in: "\nsomething went wrong\n") == "something went wrong")
    }
}
