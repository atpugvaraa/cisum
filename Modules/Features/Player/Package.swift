// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Player",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Player", targets: ["Player"])
    ],
    dependencies: [
        .package(path: "../../Shared/Models"),
        .package(path: "../../Shared/Utilities"),
        .package(path: "../../Shared/DesignSystem"),
        .package(path: "../../Shared/Services"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0"),
        .package(name: "YouTubeSDK", path: "../../../Packages/StreamingKit/YouTubeSDK"),
        .package(name: "SpotifySDK", path: "../../../Packages/StreamingKit/SpotifySDK"),
        .package(name: "iTunesKit", path: "../../../Packages/StreamingKit/iTunesKit"),
    ],
    targets: [
        .target(
            name: "Player",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "Utilities", package: "Utilities"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Services", package: "Services"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "YouTubeSDK", package: "YouTubeSDK"),
                .product(name: "SpotifySDK", package: "SpotifySDK"),
                .product(name: "iTunesKit", package: "iTunesKit")
            ]
        )
    ]
)