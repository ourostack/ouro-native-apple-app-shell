// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OuroAppShell",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "OuroAppShellCore", targets: ["OuroAppShellCore"])
    ],
    targets: [
        .target(name: "OuroAppShellCore"),
        .testTarget(
            name: "OuroAppShellCoreTests",
            dependencies: ["OuroAppShellCore"]
        )
    ]
)
