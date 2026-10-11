// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ShotBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ShotBar", path: "Sources/ShotBar")
    ]
)
