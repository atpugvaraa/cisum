// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Artists",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Artists",
            targets: ["Artists"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/Models"),
        .package(path: "../../Shared/Utilities"),
        .package(path: "../../Shared/Services"),
        .package(path: "../../Shared/DesignSystem"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "8.8.1")),
        .package(path: "../../../Packages/StreamingKit/YouTubeSDK"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Artists",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "Utilities", package: "Utilities"),
                .product(name: "Services", package: "Services"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "YouTubeSDK", package: "YouTubeSDK")
            ],
        ),

    ],
    swiftLanguageModes: [.v6]
)