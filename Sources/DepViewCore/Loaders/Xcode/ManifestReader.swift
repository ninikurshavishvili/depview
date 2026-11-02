import Foundation

/// The parts of a package manifest that decide which packages it really uses.
struct Manifest: Equatable, Sendable {
    struct Dependency: Equatable, Sendable {
        let identity: String
        /// The traits it turns on in that package, e.g. ["default"].
        let traits: [String]
    }

    enum Use: Equatable, Sendable {
        case product(name: String, package: String)
        /// A bare name: a target in the same package, or a product of a dependency.
        case byName(String)
    }

    struct TargetUse: Equatable, Sendable {
        let use: Use
        /// The use only counts when one of these traits is on. Empty means always.
        let traits: [String]
    }

    var name: String
    var dependencies: [Dependency]
    var products: [String]
    var targets: Set<String>
    /// What its targets use, leaving out test targets.
    var uses: [TargetUse]
    /// Each trait and the traits it turns on, including "default".
    var traits: [String: [String]]
}

/// Reads a package's manifest from its folder.
protocol ManifestReader: Sendable {
    func manifest(ofPackageAt folder: URL) throws -> Manifest
}

/// Runs `swift package dump-package`. The scratch folder is a temporary one,
/// so nothing gets written into the checkouts Xcode owns.
struct DumpPackageReader: ManifestReader {
    func manifest(ofPackageAt folder: URL) throws -> Manifest {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("depview-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let output = try SwiftCLI.run(["package", "--scratch-path", scratch.path, "dump-package"], in: folder)
        return try Self.parse(output)
    }

    static func parse(_ output: Data) throws -> Manifest {
        guard let start = output.firstIndex(of: UInt8(ascii: "{")),
              let json = try? JSONSerialization.jsonObject(with: Data(output[start...])) as? [String: Any],
              let name = json["name"] as? String else {
            throw DepViewError.unreadableOutput
        }

        // Each dependency is {"sourceControl": [...]}, {"fileSystem": [...]} or {"registry": [...]},
        // and the one entry inside has the identity and the traits it turns on.
        let dependencies = (json["dependencies"] as? [[String: Any]] ?? []).compactMap { entry -> Manifest.Dependency? in
            guard let details = (entry.values.first as? [[String: Any]])?.first,
                  let identity = details["identity"] as? String else { return nil }
            // Before traits existed, every dependency got its defaults.
            let traits = (details["traits"] as? [[String: Any]])?
                .filter { $0["condition"] == nil || $0["condition"] is NSNull }
                .compactMap { $0["name"] as? String } ?? ["default"]
            return Manifest.Dependency(identity: identity, traits: traits)
        }

        let targets = json["targets"] as? [[String: Any]] ?? []
        var uses: [Manifest.TargetUse] = []
        for target in targets where target["type"] as? String != "test" {
            // {"product": [name, package, aliases, condition]}, {"byName": [name, condition]}
            // or {"target": [name, condition]}. Targets in the same package don't matter here.
            for dependency in target["dependencies"] as? [[String: Any]] ?? [] {
                if let product = dependency["product"] as? [Any], let name = product.first as? String,
                   let package = product.count > 1 ? product[1] as? String : nil {
                    uses.append(Manifest.TargetUse(use: .product(name: name, package: package),
                                                   traits: traitCondition(product.count > 3 ? product[3] : nil)))
                } else if let byName = dependency["byName"] as? [Any], let name = byName.first as? String {
                    uses.append(Manifest.TargetUse(use: .byName(name),
                                                   traits: traitCondition(byName.count > 1 ? byName[1] : nil)))
                }
            }
            // Build tool plugins from other packages, e.g. {"plugin": ["SwiftLint", "SwiftLintPlugins"]}.
            for usage in target["pluginUsages"] as? [[String: Any]] ?? [] {
                if let plugin = usage["plugin"] as? [Any], let name = plugin.first as? String,
                   let package = plugin.count > 1 ? plugin[1] as? String : nil {
                    uses.append(Manifest.TargetUse(use: .product(name: name, package: package), traits: []))
                }
            }
        }

        var traits: [String: [String]] = [:]
        for trait in json["traits"] as? [[String: Any]] ?? [] {
            if let name = trait["name"] as? String {
                traits[name] = trait["enabledTraits"] as? [String] ?? []
            }
        }

        return Manifest(name: name,
                        dependencies: dependencies,
                        products: (json["products"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String },
                        targets: Set(targets.compactMap { $0["name"] as? String }),
                        uses: uses,
                        traits: traits)
    }

    /// The traits in a condition like {"platformNames": [], "traits": ["Sharing"]}.
    private static func traitCondition(_ condition: Any?) -> [String] {
        (condition as? [String: Any])?["traits"] as? [String] ?? []
    }
}

extension Manifest {
    /// The packages this manifest's targets really use, in the order it lists its dependencies.
    /// `manifests` (by identity) resolves bare names to the dependency whose product they name.
    func usedPackages(traitsOn enabled: Set<String>, manifests: [String: Manifest]) -> [String] {
        var used: Set<String> = []
        for target in uses where target.traits.isEmpty || !enabled.isDisjoint(with: target.traits) {
            let match: Dependency?
            switch target.use {
            case .product(_, let package):
                match = dependencies.first {
                    $0.identity == package.lowercased() || manifests[$0.identity]?.name == package
                }
            case .byName(let name):
                guard !targets.contains(name) else { continue }
                match = dependencies.first {
                    $0.identity == name.lowercased() || manifests[$0.identity]?.products.contains(name) == true
                }
            }
            if let match { used.insert(match.identity) }
        }
        return dependencies.map(\.identity).filter(used.contains)
    }

    /// Expands traits with the ones each turns on, so "default" becomes the package's default traits.
    func expand(_ requested: Set<String>) -> Set<String> {
        var result: Set<String> = []
        var queue = Array(requested)
        while let trait = queue.popLast() {
            if result.insert(trait).inserted {
                queue.append(contentsOf: traits[trait] ?? [])
            }
        }
        return result
    }
}
