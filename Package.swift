// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "halfspace",
    targets: [
        .executableTarget(
            name: "halfspace",
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
