// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RumboCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "RumboCore", targets: ["RumboCore"]),
    ],
    targets: [
        .target(name: "RumboCore"),
        .testTarget(name: "RumboCoreTests", dependencies: ["RumboCore"]),
    ]
)
