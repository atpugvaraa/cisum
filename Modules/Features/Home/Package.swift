// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Home",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Home",
            targets: ["Home"],
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/DesignSystem"),
        .package(path: "../../Shared/Utilities"),
        .package(name: "YouTubeSDK", path: "../../../Packages/StreamingKit/YouTubeSDK"),
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: [
                "DesignSystem",
                "Utilities",
                "YouTubeSDK"
            ],
        ),
    ],
    swiftLanguageModes: [.v6]
)
