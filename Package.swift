// swift-tools-version:6.0

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
      .executableTarget(
        name: "Cli",
        dependencies: ["SourceMapper"]),
    ]
)
