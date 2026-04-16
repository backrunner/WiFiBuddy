// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WiFiBuddy",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WiFiBuddy",
            targets: ["WiFiBuddy"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", branch: "release/6.2")
    ],
    targets: [
        .executableTarget(
            name: "WiFiBuddy",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WiFiBuddyTests",
            dependencies: [
                "WiFiBuddy",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
