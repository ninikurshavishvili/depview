import Foundation
import Testing
@testable import DepViewCore

struct ProjectDetectorTests {
    /// A temporary folder holding `items`: files for names ending in .swift, folders otherwise.
    private func folder(with items: [String]) throws -> URL {
        let folder = try temporaryFolder()
        for item in items {
            let url = folder.appendingPathComponent(item)
            if item.hasSuffix(".swift") {
                try Data().write(to: url)
            } else {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
        return folder
    }

    private func describe(_ project: Project) -> String {
        switch project {
        case .swiftPackage(let folder): "package \(folder.lastPathComponent)"
        case .xcode(let project): "xcode \(project.lastPathComponent)"
        }
    }

    @Test func swiftPackageFolder() throws {
        let folder = try folder(with: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(describe(try ProjectDetector.detect(folder)) == "package \(folder.lastPathComponent)")
    }

    @Test func pathToPackageSwiftMeansItsFolder() throws {
        let folder = try folder(with: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: folder) }
        let project = try ProjectDetector.detect(folder.appendingPathComponent("Package.swift"))
        #expect(describe(project) == "package \(folder.lastPathComponent)")
    }

    @Test func packageWinsOverAnExampleProject() throws {
        let folder = try folder(with: ["Package.swift", "Example.xcodeproj"])
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(describe(try ProjectDetector.detect(folder)) == "package \(folder.lastPathComponent)")
    }

    @Test func folderWithOneProject() throws {
        let folder = try folder(with: ["App.xcodeproj", "App"])
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(describe(try ProjectDetector.detect(folder)) == "xcode App.xcodeproj")
    }

    @Test func workspaceWinsOverItsProject() throws {
        let folder = try folder(with: ["App.xcodeproj", "App.xcworkspace", "Pods/Pods.xcodeproj"])
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(describe(try ProjectDetector.detect(folder)) == "xcode App.xcworkspace")
    }

    @Test func pathToAProject() throws {
        let folder = try folder(with: ["App.xcodeproj"])
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(describe(try ProjectDetector.detect(folder.appendingPathComponent("App.xcodeproj"))) == "xcode App.xcodeproj")
    }

    @Test func severalProjectsThrows() throws {
        let folder = try folder(with: ["B.xcodeproj", "A.xcodeproj"])
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(throws: DepViewError.severalProjects(path: folder.path, names: ["A.xcodeproj", "B.xcodeproj"])) {
            try ProjectDetector.detect(folder)
        }
    }

    @Test func folderWithNoProjectThrows() throws {
        let folder = try folder(with: ["README.md"])
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(throws: DepViewError.noProject(path: folder.path)) {
            try ProjectDetector.detect(folder)
        }
    }

    @Test func missingFolderThrows() {
        let folder = URL(fileURLWithPath: "/no/such/folder")
        #expect(throws: DepViewError.folderNotFound(path: folder.path)) {
            try ProjectDetector.detect(folder)
        }
    }
}
