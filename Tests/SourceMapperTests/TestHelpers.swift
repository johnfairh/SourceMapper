//
//  TestHelpers.swift
//  SourceMapperTests
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

import Foundation
import SourceMapper

extension SourceMap {
    init(url: URL) throws {
        try self.init(try Data(contentsOf: url))
    }

    static let fixturesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")

    init(fixtureName: String) throws {
        try self.init(url: Self.fixturesURL.appendingPathComponent(fixtureName))
    }
}
