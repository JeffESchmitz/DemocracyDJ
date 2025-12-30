// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // The library that the iOS App will import
        .library(
            name: "Shared",
            targets: ["Shared"]),
    ],
    targets: [
        .target(
            name: "Shared",
            dependencies: []
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"]
        ),
    ]
)
