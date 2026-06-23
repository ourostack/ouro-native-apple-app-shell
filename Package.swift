// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OuroAppShell",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "OuroAppShellCore", targets: ["OuroAppShellCore"]),
        .library(name: "OuroAppShellUI", targets: ["OuroAppShellUI"]),
        .executable(name: "OuroAppShellUISurfaceProbe", targets: ["OuroAppShellUISurfaceProbe"])
    ],
    targets: [
        .target(name: "OuroAppShellCore"),
        .target(
            name: "OuroAppShellUI",
            dependencies: ["OuroAppShellCore"]
        ),
        .executableTarget(
            name: "OuroAppShellUISurfaceProbe",
            dependencies: ["OuroAppShellCore", "OuroAppShellUI"]
        ),
        .testTarget(
            name: "OuroAppShellCoreTests",
            dependencies: ["OuroAppShellCore"]
        ),
        .testTarget(
            name: "OuroAppShellUITests",
            dependencies: ["OuroAppShellCore", "OuroAppShellUI"]
        )
    ]
)
