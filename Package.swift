// swift-tools-version:5.9
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Paulo Borini

import PackageDescription

let package = Package(
    name: "hexa",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Hexa", targets: ["Hexa"]),
        .executable(name: "FanControlHelper", targets: ["FanControlHelper"]),
        .library(name: "NowPlayingAdapter", type: .dynamic, targets: ["NowPlayingAdapter"])
    ],
    targets: [
        .systemLibrary(
            name: "VMStatisticsCompat",
            path: "Sources/VMStatisticsCompat"
        ),
        .target(
            name: "FanControlCore",
            path: "Sources/FanControlCore"
        ),
        .target(
            name: "NotchPlaybackCore",
            path: "Sources/NotchPlaybackCore"
        ),
        .executableTarget(
            name: "Hexa",
            dependencies: ["VMStatisticsCompat", "FanControlCore", "NotchPlaybackCore"],
            path: "Sources/Hexa",
            resources: [
                .copy("Resources/Fonts"),
                .copy("Resources/Brand"),
                .copy("Resources/Icons"),
                .copy("Resources/ReleaseVersion.txt")
            ]
        ),
        .executableTarget(
            name: "FanControlHelper",
            dependencies: ["FanControlCore"],
            path: "Sources/FanControlHelper"
        ),
        .target(
            name: "NowPlayingAdapter",
            dependencies: ["NotchPlaybackCore"],
            path: "Sources/NowPlayingAdapter"
        ),
        .testTarget(
            name: "hexaTests",
            dependencies: ["Hexa", "FanControlCore"],
            path: "Tests/hexaTests"
        )
    ]
)
