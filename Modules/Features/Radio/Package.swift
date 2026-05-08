// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Radio",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Radio",
            targets: ["Radio"]
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
            name: "Radio",
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
