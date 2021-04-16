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
    func testEmptyRoundTrip() throws {
        let empty = SourceMap()
        let serialized = try empty.encode()
        let deserialized = try SourceMap(data: serialized)
        XCTAssertEqual(empty, deserialized)
    }

    func testLoading() throws {
        try ["jazzy.css.map.dart", "jazzy.css.map.libsass"].forEach { fixtureName in
            let map = try SourceMap(fixtureName: fixtureName)
            XCTAssertEqual(SourceMap.VERSION, map.version)
            if let file = map.file {
                XCTAssertEqual("jazzy.css.css", file)
            }
            XCTAssertEqual(1, map.sources.count)
            XCTAssertTrue(map.sources[0].url.hasSuffix("jazzy.css.scss"))

            let mappings = try map.getSegments()
            print(mappings.mappingsDescription)

            // stubborn libsass...
            let row: Int
            if fixtureName.contains("dart") {
                row = 30
            } else {
                row = 26
            }

            let mapped = try XCTUnwrap(try map.map(line: row, column: 22))
            let pos = try XCTUnwrap(mapped.sourcePos)
            XCTAssertEqual(25, pos.line)
            XCTAssertTrue(pos.column >= 14)
        }
    }
}

extension SourceMap.Source {
    var url: String {
        switch self {
        case .inline(let url, _), .remote(let url): return url
        }
    }
}
