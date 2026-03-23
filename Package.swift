// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WalletAssignment",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "WalletCore",
            targets: ["WalletCore"]
        ),
        .executable(
            name: "WalletAssignment",
            targets: ["WalletAssignment"]
        ),
    ],
    targets: [
        .target(
            name: "WalletCore"
        ),
        .executableTarget(
            name: "WalletAssignment",
            dependencies: ["WalletCore"]
        ),
        .testTarget(
            name: "WalletCoreTests",
            dependencies: ["WalletCore"]
        ),
    ]
)
