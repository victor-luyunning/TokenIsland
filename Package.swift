// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TokenIsland",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TokenIsland", targets: ["TokenIsland"])
    ],
    targets: [
        .executableTarget(
            name: "TokenIsland",
            path: "Sources/TokenIsland"
        )
    ]
)
