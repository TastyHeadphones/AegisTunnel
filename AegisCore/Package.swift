// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AegisCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AegisCore",
            targets: ["AegisCore"]
        )
    ],
    targets: [
        .target(
            name: "AegisCore"
        ),
        .testTarget(
            name: "AegisCoreTests",
            dependencies: ["AegisCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
