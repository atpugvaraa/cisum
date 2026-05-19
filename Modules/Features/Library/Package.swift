// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Library",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Library", targets: ["Library"])
    ],
    dependencies: [
        .package(path: "../../Shared/Models"),
        .package(path: "../../Shared/Services"),
        .package(path: "../../Shared/DesignSystem"),
        .package(path: "../../Shared/Utilities"),
        .package(path: "../Artists"),
        .package(path: "../Albums"),
        .package(path: "../Playlists"),
        .package(name: "SpotifySDK", path: "../../../Packages/StreamingKit/SpotifySDK"),
        .package(name: "YouTubeSDK", path: "../../../Packages/StreamingKit/YouTubeSDK"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "8.8.1"))
    ],
    targets: [
        .target(
            name: "Library",
            dependencies: [
                "Models",
                "Services",
                "DesignSystem",
                "Utilities",
                "Artists",
                "Albums",
                "Playlists",
                .product(name: "SpotifySDK", package: "SpotifySDK"),
                .product(name: "YouTubeSDK", package: "YouTubeSDK"),
                .product(name: "Kingfisher", package: "Kingfisher")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
