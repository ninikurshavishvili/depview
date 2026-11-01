// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "depview",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "depview", targets: ["depview"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "depview",
            dependencies: [
                "DepViewCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(name: "DepViewCore"),
        .testTarget(
            name: "DepViewCoreTests",
            dependencies: ["DepViewCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
