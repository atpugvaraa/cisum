// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Authentication",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(
            name: "Authentication",
            targets: ["Authentication"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/Services"),
        .package(path: "../../Shared/DesignSystem"),
    ],
    targets: [
        .target(
            name: "Authentication",
            dependencies: [
                .product(name: "Services", package: "Services"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
