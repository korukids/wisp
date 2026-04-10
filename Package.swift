// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Wisp",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Wisp",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Wisp",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "WispTests",
            dependencies: ["Wisp"],
            path: "WispTests",
            resources: [
                .process("Fixtures"),
            ]
        ),
    ]
)
