// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SourceMapper",
    products: [
      .library(
        name: "SourceMapper",
        targets: ["SourceMapper"]),
      .executable(
        name: "srcmapcat",
        targets: ["Cli"]),
    ],
    targets: [
      .target(
        name: "SourceMapper",
        dependencies: []),
      .testTarget(
        name: "SourceMapperTests",
        dependencies: ["SourceMapper"],
        exclude: ["Fixtures"]),
      .target(
        name: "Cli",
        dependencies: ["SourceMapper"]),
    ]
)
