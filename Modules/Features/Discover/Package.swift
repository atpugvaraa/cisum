// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Discover",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Discover", targets: ["Discover"])
    ],
    dependencies: [
        .package(path: "../../Shared/DesignSystem"),
        .package(path: "../../Shared/Utilities"),
        .package(path: "../../Shared/Services"),
        .package(path: "../../../Packages/StreamingKit/YouTubeSDK"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "8.8.1"))
    ],
    targets: [
        .target(
            name: "Discover",
            dependencies: [
                "DesignSystem",
                "Utilities",
                "Services",
                .product(name: "YouTubeSDK", package: "YouTubeSDK"),
                .product(name: "Kingfisher", package: "Kingfisher")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
