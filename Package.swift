// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NSAssetsCLI",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "nsassets", targets: ["NSAssetsCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "NSAssetsCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "NSAssetsCLITests",
            dependencies: ["NSAssetsCLI"],
            exclude: ["NSAssetsCLI.xctestplan"]
        )
    ]
)
