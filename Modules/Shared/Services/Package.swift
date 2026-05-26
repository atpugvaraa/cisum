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
        .package(path: "../../../Packages/StreamingKit/YouTubeSDK"),
        .package(path: "../../../Packages/StreamingKit/ProviderSDK"),
        .package(path: "../../../Packages/StreamingKit/SpotifySDK"),

        .package(url: "https://github.com/clerk/clerk-ios", from: "1.1.3"),
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
        .package(url: "https://github.com/PostHog/posthog-ios.git", from: "3.58.0"),
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
                .product(name: "ProviderSDK", package: "ProviderSDK"),
                .product(name: "SpotifySDK", package: "SpotifySDK"),

                .product(name: "ClerkKit", package: "clerk-ios"),
                .product(name: "ClerkKitUI", package: "clerk-ios"),
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "PostHog", package: "posthog-ios"),
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
