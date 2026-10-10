// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "farcast-core",
    platforms: [.macOS("27.0")],
    products: [.library(name: "farcast-core", targets: ["FarcastCore"])],
    targets: [
        .target(
            name: "FarcastCore", path: "Farcast",
            exclude: ["App", "Features", "Protocols", "Native", "Native-Bridge.h", "Assets.xcassets", "AppIcon.icon"],
            sources: ["Domain", "Persistence", "Shared"]
        ),
        .testTarget(name: "CoreTests", dependencies: ["FarcastCore"], path: "Tests/CoreTests"),
    ],
    swiftLanguageModes: [.v5]
)
