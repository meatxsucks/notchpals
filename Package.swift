// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchPals",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "NotchPals", path: "Sources/NotchPals"),
        .testTarget(name: "NotchPalsTests", dependencies: ["NotchPals"], path: "Tests/NotchPalsTests"),
    ]
)
