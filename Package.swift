// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Assinafy",
    platforms: [
        .iOS(.v16),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "Assinafy",
            targets: ["Assinafy"]
        ),
    ],
    targets: [
        .target(
            name: "Assinafy",
            path: "Sources/Assinafy"
        ),
        .testTarget(
            name: "AssinafyTests",
            dependencies: ["Assinafy"],
            path: "Tests/AssinafyTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
