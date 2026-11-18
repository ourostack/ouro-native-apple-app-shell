// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OuroAppShell",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "OuroAppShellCore", targets: ["OuroAppShellCore"]),
        .library(name: "OuroAppShellContract", targets: ["OuroAppShellContract"]),
        .library(name: "OuroAppShellConsumerTesting", targets: ["OuroAppShellConsumerTesting"]),
        .library(name: "OuroAppShellAppKit", targets: ["OuroAppShellAppKit"]),
        .library(name: "OuroAppShellUI", targets: ["OuroAppShellUI"]),
        .executable(name: "OuroAppShellUISurfaceProbe", targets: ["OuroAppShellUISurfaceProbe"])
    ],
    dependencies: [
        // Any 1.x from 1.1, so an app on a newer minor of ouro-ui-apple still resolves with the shell (ouro-md#194
        // could not resolve when it moved to 1.1 and the shell allowed only 1.0.x).
        .package(url: "https://github.com/ourostack/ouro-ui-apple.git", from: "1.1.0"),
    ],
    targets: [
        .target(name: "OuroAppShellCore"),
        .target(
            name: "OuroAppShellContract",
            dependencies: ["OuroAppShellCore"]
        ),
        .target(
            name: "OuroAppShellConsumerTesting",
            dependencies: ["OuroAppShellContract"]
        ),
        .target(
            name: "OuroAppShellAppKit",
            dependencies: ["OuroAppShellUI"]
        ),
        .target(
            name: "OuroAppShellUI",
            dependencies: [
                "OuroAppShellCore",
                .product(name: "OuroHX", package: "ouro-ui-apple"),
            ]
        ),
        .executableTarget(
            name: "OuroAppShellUISurfaceProbe",
            dependencies: ["OuroAppShellCore", "OuroAppShellUI"]
        ),
        .testTarget(
            name: "OuroAppShellCoreTests",
            dependencies: ["OuroAppShellCore", "OuroAppShellAppKit"]
        ),
        .testTarget(
            name: "OuroAppShellContractTests",
            dependencies: ["OuroAppShellContract"]
        ),
        .testTarget(
            name: "OuroAppShellConsumerTestingTests",
            dependencies: ["OuroAppShellConsumerTesting"]
        ),
        .testTarget(
            name: "OuroAppShellUITests",
            dependencies: ["OuroAppShellCore", "OuroAppShellUI"]
        )
    ]
)
