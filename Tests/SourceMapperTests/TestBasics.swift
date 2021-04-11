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
        try ["jazzy.css.map.dart", "jazzy.css.map.libsass"].forEach {
            let map = try SourceMap(fixtureName: $0)
            XCTAssertEqual(SourceMap.VERSION, map.version)
            if let file = map.file {
                XCTAssertEqual("jazzy.css.css", file)
            }
            XCTAssertEqual(1, map.sources.count)
            XCTAssertTrue(map.sources[0].url.hasSuffix("jazzy.css.scss"))
            // add a couple of map tests

            let mappings = try map.unpackMappings()
            print(mappings)
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
