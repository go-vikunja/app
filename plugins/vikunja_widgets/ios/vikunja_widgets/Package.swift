// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "vikunja_widgets",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "vikunja-widgets", targets: ["vikunja_widgets"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "vikunja_widgets",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
