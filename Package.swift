// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TrustAnchor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "trustanchor-daemon", targets: ["TrustAnchorDaemon"]),
        .executable(name: "trustanchor", targets: ["TrustAnchorCLI"]),
        .library(name: "TrustAnchorLib", targets: ["TrustAnchorLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        // Core Logic
        .target(
            name: "TrustAnchorLib",
            dependencies: [],
            path: "Sources/TrustAnchorLib"
        ),
        // Daemon (Privileged)
        .executableTarget(
            name: "TrustAnchorDaemon",
            dependencies: ["TrustAnchorLib"],
            path: "Sources/TrustAnchorDaemon",
            linkerSettings: [
                .unsafeFlags(["-L/usr/lib", "-lEndpointSecurity"])
            ]
        ),
        // CLI (User)
        .executableTarget(
            name: "TrustAnchorCLI",
            dependencies: [
                "TrustAnchorLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/TrustAnchorCLI"
        ),
    ]
)
