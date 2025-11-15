// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PureBarKit",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "PureBarKit",
      targets: ["PureBarKit"]
    ),
  ],
  dependencies: [
    .package(path: "../PureBarTools"),
  ],
  targets: [
    .target(
      name: "PureBarKit",
      path: "Sources",
      resources: [
        .process("LunarCalendar/Resources"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ],
      plugins: [
        .plugin(name: "SwiftLint", package: "PureBarTools"),
      ]
    ),

    .testTarget(
      name: "PureBarKitTests",
      dependencies: ["PureBarKit"],
      path: "Tests",
      plugins: [
        .plugin(name: "SwiftLint", package: "PureBarTools"),
      ]
    ),
  ]
)
