//
//  TestMappings.swift
//  SourceMapperTests
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

@testable import SourceMapper
import XCTest

/// Mappings encode/decode, weird special cases and errors
///
/// So, in TestBasics we verify that we can load actual mappnigs and get correct results out.
/// Meaning here we can verify round-tripping through mappings and conclude all is well.
class TestMappings: XCTestCase {

    func checkRoundtrip(_ map: SourceMap) throws {
        let serialized = try map.encode(continueOnError: false)
        let newMap = try SourceMap(data: serialized)
        XCTAssertEqual(map, newMap)
        let mapSegs = try map.getSegments()
        let newMapSegs = try newMap.getSegments()
        if mapSegs != newMapSegs {
            print("mapSegs:\n\(mapSegs.mappingsDescription)\nnewMapSegs:\n\(newMapSegs.mappingsDescription)")
            XCTFail("Map segs not equal")
        }
    }

    func testNormalMappingScenarios() throws {
        let map = SourceMap()
        map.sources = [.remote(url: "source1.css"), .remote(url: "source2.css")]
        map.names = ["Name1", "Name2"]
        let line1: [SourceMap.Segment] = [
            .init(firstColumn: 0),
            .init(columns: 8..<20, sourcePos: SourceMap.SourcePos(source: 0, line: 4, column: 12)),
            .init(firstColumn: 20, sourcePos: SourceMap.SourcePos(source: 1, line: 12000, column: 20, name: 1))
        ]
        let line2: [SourceMap.Segment] = [
            .init(columns: 12...18, sourcePos: SourceMap.SourcePos(source: 0, line: 8, column: 14))
        ]
        map.setSegments([line1, line2])

        try checkRoundtrip(map)
    }
}
