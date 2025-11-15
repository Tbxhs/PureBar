// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Modules",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "AppKitControls",
      targets: ["AppKitControls"]
    ),
    .library(
      name: "AppKitExtensions",
      targets: ["AppKitExtensions"]
    ),
  ],
  dependencies: [
    .package(path: "../PureBarTools"),
  ],
  targets: [
    .target(
      name: "AppKitControls",
      dependencies: ["AppKitExtensions"],
      path: "Sources/AppKitControls",
      plugins: [
        .plugin(name: "SwiftLint", package: "PureBarTools"),
      ]
    ),
    .target(
      name: "AppKitExtensions",
      path: "Sources/AppKitExtensions",
      plugins: [
        .plugin(name: "SwiftLint", package: "PureBarTools"),
      ]
    ),
  ]
)
