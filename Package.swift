// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexRoute",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CodexRoute", targets: ["CodexRoute"])],
    targets: [
        .executableTarget(name: "CodexRoute"),
        .testTarget(name: "CodexRouteTests", dependencies: ["CodexRoute"])
    ]
)
