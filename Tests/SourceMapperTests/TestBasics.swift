//
//  TestBasics.swift
//  SourceMapperTests
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

@testable import SourceMapper
import XCTest

/// Basic flows of the use cases
class TestBasics: XCTestCase {
    func testRoundTrip() throws {
        var empty = SourceMap()
        let serialized = try empty.encode()
        let deserialized = try SourceMap(data: serialized)
        XCTAssertEqual(empty, deserialized)
    }
}
