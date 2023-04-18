//
//  TestJSON.swift
//  SourceMapperTests
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

@testable import SourceMapper
import XCTest

/// JSON code/decode logic and error handling
class TestJSON: XCTestCase {
    func testMissingFields() throws {
        XCTAssertThrows(Swift.DecodingError.self) {
            let map = try SourceMapC(string: "{}")
            XCTFail("Managed to decode bad map: \(map)")
        }
    }

    func testBadVersion() throws {
        let badVersionJSON = """
        {
          "version": 4,
          "sources": [],
          "names": [],
          "mappings": ""
        }
        """

        XCTAssertSourceMapError(.invalidFormat(4)) {
            let map = try SourceMapC(string: badVersionJSON)
            XCTFail("Managed to decode bad map: \(map)")
        }
    }

    func testInconsistentSources() throws {
        let badSourcesJSON = """
        {
          "version": 3,
          "sources": ["a", "b", "c"],
          "sourcesContent": ["contents of a", null],
          "names": [],
          "mappings": ""
        }
        """

        XCTAssertSourceMapError(.inconsistentSources(sourcesCount: 3, sourcesContentCount: 2)) {
            let map = try SourceMapC(string: badSourcesJSON)
            XCTFail("Managed to decode bad map: \(map)")
        }
    }

    func testSourceContent() throws {
        let sourcedJSON = """
        {
          "version": 3,
          "sources": ["a", "b"],
          "sourcesContent": ["contents of a", null],
          "names": [],
          "mappings": ""
        }
        """
        let map = try SourceMapC(string: sourcedJSON)
        XCTAssertEqual(2, map.sources.count)
        XCTAssertEqual("contents of a", map.sources[0].content)
        XCTAssertNil(map.sources[1].content)

        let encoded = try map.encode()
        let map2 = try SourceMapC(data: encoded)
        XCTAssertEqual(map, map2)
    }

    func testBadMapping() throws {
        let json = """
        {
          "version": 3,
          "sources": ["a"],
          "names": [],
          "mappings": "AAA"
        }
        """
        XCTAssertSourceMapError(.invalidVLQStringLength([0,0,0])) {
            _ = try SourceMapC(string: json, checkMappings: true)
        }
    }
}
