<!--
SourceMapper
README.md
Distributed under the MIT license, see LICENSE.
-->

![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-green)
[![codecov](https://codecov.io/gh/johnfairh/SourceMapper/branch/main/graph/badge.svg?token=0NAP6IA9EB)](https://codecov.io/gh/johnfairh/SourceMapper)
![Tests](https://github.com/johnfairh/SourceMapper/workflows/Tests/badge.svg)

# SourceMapper

Simple Swift implementation of the
[SourceMap](https://docs.google.com/document/d/1U1RGAehQwRypUTovF1KRlpiOFze0b-_2gc6fAH0KY0k)
specification: create, load, query, modify, and save source maps.

## Examples

```swift
let map = try SourceMap(Data(contentsOf: mapURL))
print(map.file)

let unpackedMap = try UnpackedSourceMap(map)
let segment = unpackedMap.map(line: 12, column: 0)
```

```swift
var map = SourceMap()
map.sources = [.remote("a.scss")]
map.sourceRoot = "./../src/"
try map.set(segments: ..., validate: true)
let mapData = map.encode()
```

## Documentation

* [API documentation](https://johnfairh.github.io/SourceMapper/)
* [Dash docset](https://johnfairh.github.io/SourceMapper/docsets/SourceMapper.tgz)

No support for:
* Extension fields
* Index map format

## Requirements

* Swift 5.7
* macOS 10.10 (tested on macOS 12.0 IA64)
* Linux (tested on Ubuntu 18.04.5)
* Windows 10, Swift 5.7 (tested in CI only)

## Installation

Only with Swift Package Manager, via Xcode or directly:

Package dependency:
```swift
.package(name: "SourceMapper",
         url: "https://github.com/johnfairh/SourceMapper.git",
         from: "2.0.0")
```

## Contributions

Welcome: open an issue / johnfairh@gmail.com / @johnfairh@mastodon.social

## License

Distributed under the MIT license.
