// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Core", targets: ["Core"])
    ],
    dependencies: [
        .package(path: "../Features/Home"),
        .package(path: "../Features/Discover"),
        .package(path: "../Features/Library"),
        .package(path: "../Features/Player"),
        .package(path: "../Features/Search"),
        .package(path: "../Features/Profile"),
        .package(path: "../Shared/DesignSystem"),
        .package(path: "../Shared/Services"),
        .package(path: "../Shared/Models"),
        .package(path: "../Shared/Utilities")
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: [
                "Home",
                "Discover",
                "Library",
                "Player",
                "Search",
                "Profile",
                "DesignSystem",
                "Services",
                "Models",
                "Utilities"
            ]
        )
    ]
)
