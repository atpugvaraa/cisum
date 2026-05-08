// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Playlists",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Playlists",
            targets: ["Playlists"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/Models"),
        .package(path: "../../Shared/Utilities"),
        .package(path: "../../Shared/Services"),
        .package(path: "../../Shared/DesignSystem"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Playlists",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "Utilities", package: "Utilities"),
                .product(name: "Services", package: "Services"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
