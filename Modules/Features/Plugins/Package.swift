// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Plugins",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Plugins",
            targets: ["Plugins"]
        )
    ],
    dependencies: [
        .package(path: "../../Shared/Services"),
        .package(path: "../../../Packages/StreamingKit/ProviderSDK"),
        .package(path: "../../../Packages/StreamingKit/YouTubeSDK")
    ],
    targets: [
        .target(
            name: "Plugins",
            dependencies: [
                .product(name: "Services", package: "Services"),
                .product(name: "ProviderSDK", package: "ProviderSDK"),
                .product(name: "YouTubeSDK", package: "YouTubeSDK")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
