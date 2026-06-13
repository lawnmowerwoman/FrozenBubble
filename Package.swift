// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FrozenBubbleSwift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FrozenBubbleSwift", targets: ["FrozenBubbleSwift"])
    ],
    targets: [
        .executableTarget(
            name: "FrozenBubbleSwift",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
