// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SimpleNetworking",
    products: [
        .library(
            name: "SimpleNetworking",
            targets: ["SimpleNetworking"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SimpleNetworking",
            dependencies: []),
        .testTarget(
            name: "SimpleNetworkingTests",
            dependencies: ["SimpleNetworking"]),
    ]
)
