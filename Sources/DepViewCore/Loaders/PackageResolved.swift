import Foundation

/// A package pinned in Package.resolved.
struct PackagePin: Equatable {
    let identity: String
    let location: String
    /// A release number, else a branch name, else a short commit hash.
    let version: String?
    let pin: Pin?
}

/// Reads Package.resolved in all three formats: version 1 (Xcode 12 and 13),
/// and versions 2 and 3 (Xcode 14 and later).
enum PackageResolved {
    static func pins(from data: Data) -> [PackagePin]? {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return nil }
        if let pins = file.pins {
            return pins.map {
                PackagePin(identity: $0.identity, location: $0.location, version: $0.state.display, pin: $0.state.pin)
            }
        }
        return file.object?.pins.map {
            PackagePin(identity: packageIdentity(for: $0.repositoryURL), location: $0.repositoryURL,
                       version: $0.state.display, pin: $0.state.pin)
        }
    }

    private struct File: Decodable {
        let pins: [Entry]?      // Versions 2 and 3.
        let object: Object?     // Version 1.
    }

    private struct Entry: Decodable {
        let identity: String
        let location: String
        let state: State
    }

    private struct Object: Decodable {
        let pins: [OldPin]
    }

    private struct OldPin: Decodable {
        let repositoryURL: String
        let state: State
    }

    private struct State: Decodable {
        let version: String?
        let branch: String?
        let revision: String?

        var display: String? {
            version ?? branch ?? revision.map { String($0.prefix(7)) }
        }

        var pin: Pin? {
            version != nil ? .release : branch != nil ? .branch : revision != nil ? .commit : nil
        }
    }
}
