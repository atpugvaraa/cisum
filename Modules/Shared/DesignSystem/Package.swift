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
        .package(path: "../Utilities"),
        .package(path: "../Services"),
        .package(path: "../../../Packages/StreamingKit/SpotifySDK"),
        .package(path: "../../../Packages/StreamingKit/YouTubeSDK"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0"),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [
                "Utilities",
                "Services",
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "SpotifySDK", package: "SpotifySDK"),
                .product(name: "YouTubeSDK", package: "YouTubeSDK"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
