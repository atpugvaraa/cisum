// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Search",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Search", targets: ["Search"])
    ],
    dependencies: [
        .package(path: "../../Shared/Models"),
        .package(path: "../../Shared/Utilities"),
        .package(path: "../../Shared/Services"),
        .package(path: "../../Shared/DesignSystem"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0"),
        .package(name: "YouTubeSDK", path: "../../../Packages/StreamingKit/YouTubeSDK"),
        .package(name: "SpotifySDK", path: "../../../Packages/StreamingKit/SpotifySDK"),
    ],
    targets: [
        .target(
            name: "Search",
            dependencies: [
                .product(name: "YouTubeSDK", package: "YouTubeSDK"),
                .product(name: "Models", package: "Models"),
                .product(name: "Utilities", package: "Utilities"),
                .product(name: "Services", package: "Services"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "SpotifySDK", package: "SpotifySDK"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
