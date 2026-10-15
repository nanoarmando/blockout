// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Blockout",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Blockout", path: "Sources/Blockout")
    ]
)
