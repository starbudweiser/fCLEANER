// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "fCLEANER",
    platforms: [.macOS(.v15)],
    targets: [
        // Motifs, parcours, purge et traductions, sans interface (testable seul)
        .target(name: "CleanCore"),
        .executableTarget(name: "fCLEANER", dependencies: ["CleanCore"]),
        .testTarget(name: "CleanCoreTests", dependencies: ["CleanCore"]),
    ],
    swiftLanguageModes: [.v5]
)
