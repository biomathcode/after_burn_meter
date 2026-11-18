// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AfterburnCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "AfterburnCore", targets: ["AfterburnCore"])],
    targets: [
        .target(name: "AfterburnCore"),
        .testTarget(name: "AfterburnCoreTests", dependencies: ["AfterburnCore"])
    ]
)

