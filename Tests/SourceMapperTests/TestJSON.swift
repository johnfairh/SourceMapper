//
//  TestJSON.swift
//  SourceMapperTests
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

@testable import SourceMapper
import Testing

extension Tag {
    @Tag static var json: Self
}

/// JSON code/decode logic and error handling
@Suite(.tags(.json))
final class TestJSON {
    @Test
    func testMissingFields() throws {
        #expect(throws: Swift.DecodingError.self) {
            let map = try SourceMap("{}")
            print("Bad map decoded: \(map)")
        }
    }

    @Test
    func testBadVersion() throws {
        let badVersionJSON = """
        {
          "version": 4,
          "sources": [],
          "names": [],
          "mappings": ""
        }
        """

        #expect(throws: SourceMapError.invalidFormat(4)) {
            let map = try SourceMap(badVersionJSON)
            print("Bad map decoded: \(map)")
        }
    }

    @Test
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

        #expect(throws: SourceMapError.inconsistentSources(sourcesCount: 3, sourcesContentCount: 2)) {
            let map = try SourceMap(badSourcesJSON)
            print("Bad map decoded: \(map)")
        }
    }

    @Test
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
        let map = try SourceMap(sourcedJSON)
        #expect(map.sources.count == 2)
        #expect("contents of a" == map.sources[0].content)
        #expect(map.sources[1].content == nil)

        let encoded = try map.encode()
        let map2 = try SourceMap(encoded)
        #expect(map == map2)
    }

    @Test
    func testBadMapping() throws {
        let json = """
        {
          "version": 3,
          "sources": ["a"],
          "names": [],
          "mappings": "AAA"
        }
        """
        #expect(throws: SourceMapError.invalidVLQStringLength([0,0,0])) {
            _ = try SourceMap(json).segments
        }
    }
}
