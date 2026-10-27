// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "rurana_widgets",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "rurana-widgets", targets: ["rurana_widgets"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "rurana_widgets",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
