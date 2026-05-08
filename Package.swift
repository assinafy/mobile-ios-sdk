// swift-tools-version: 5.9
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
    ]
)
