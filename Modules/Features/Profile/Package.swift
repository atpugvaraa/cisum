// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Profile",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Profile", targets: ["Profile"])
    ],
    dependencies: [
        .package(path: "../../Shared/Models"),
        .package(path: "../../Shared/Services"),
        .package(path: "../../Shared/DesignSystem"),
        .package(path: "../../Shared/Utilities"),
        .package(name: "YouTubeSDK", path: "../../../Packages/StreamingKit/YouTubeSDK"),
        .package(name: "SpotifySDK", path: "../../../Packages/StreamingKit/SpotifySDK"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "8.8.1"))
    ],
    targets: [
        .target(
            name: "Profile",
            dependencies: [
                "Models",
                "Services",
                "DesignSystem",
                "Utilities",
                .product(name: "YouTubeSDK", package: "YouTubeSDK"),
                .product(name: "SpotifySDK", package: "SpotifySDK"),
                .product(name: "Kingfisher", package: "Kingfisher")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
