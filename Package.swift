// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UniversalRemoteCore",
    platforms: [.macOS("27.0")],
    products: [.library(name: "UniversalRemoteCore", targets: ["UniversalRemoteCore"])],
    targets: [
        .target(
            name: "UniversalRemoteCore", path: "UniversalRemote",
            exclude: ["App", "Features", "Protocols", "Native", "Native-Bridge.h", "Assets.xcassets", "AppIcon.icon"],
            sources: ["Domain", "Persistence", "Shared"]
        ),
        .testTarget(name: "CoreTests", dependencies: ["UniversalRemoteCore"], path: "Tests/CoreTests"),
    ],
    swiftLanguageModes: [.v5]
)
