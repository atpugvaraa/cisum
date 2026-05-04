// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0"),
        .package(path: "../../../Packages/StreamingKit/SpotifySDK"),
        .package(path: "../../../Packages/StreamingKit/YouTubeSDK"),
        .package(path: "../Utilities"),
        .package(path: "../Services"),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "SpotifySDK", package: "SpotifySDK"),
                .product(name: "YouTubeSDK", package: "YouTubeSDK"),
                "Utilities",
                "Services"
            ],
            resources: [
                .process("Assets")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
