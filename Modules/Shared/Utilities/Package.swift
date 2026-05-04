// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Utilities",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Utilities", targets: ["Utilities"])
    ],
    dependencies: [
        .package(path: "../../../Packages/StreamingKit/YouTubeSDK")
    ],
    targets: [
        .target(
            name: "Utilities",
            dependencies: [
                .product(name: "YouTubeSDK", package: "YouTubeSDK")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
