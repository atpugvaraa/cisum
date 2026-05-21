// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Models",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Models",
            targets: ["Models"]
        )
    ],
    dependencies: [
        .package(path: "../../../Packages/StreamingKit/YouTubeSDK")
    ],
    targets: [
        .target(
            name: "Models",
            dependencies: [
                .product(name: "YouTubeSDK", package: "YouTubeSDK")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
