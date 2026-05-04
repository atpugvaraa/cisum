// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Services",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Services",
            targets: ["Services"]
        ),
    ],
    dependencies: [
        .package(path: "../Models"),
        .package(path: "../Utilities"),
        .package(name: "YouTubeSDK", path: "../../../Packages/StreamingKit/YouTubeSDK"),
        .package(name: "SpotifySDK", path: "../../../Packages/StreamingKit/SpotifySDK"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Services",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "Utilities", package: "Utilities"),
                .product(name: "YouTubeSDK", package: "YouTubeSDK"),
                .product(name: "SpotifySDK", package: "SpotifySDK"),
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
