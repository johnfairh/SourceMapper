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
    /// helper
    func checkRoundtrip(_ map: SourceMap, continueOnError: Bool = false) throws {
        let serialized = try map.encode(continueOnError: continueOnError)
        let newMap = try SourceMap(data: serialized)
        XCTAssertEqual(map, newMap)
        let mapSegs = try map.getSegments()
        let newMapSegs = try newMap.getSegments()
        if mapSegs != newMapSegs {
            print("mapSegs:\n\(mapSegs.mappingsDescription)\nnewMapSegs:\n\(newMapSegs.mappingsDescription)")
            XCTFail("Map segs not equal")
        }
    }

    /// Basic stepping through mappings coder, +ve, -ve, multi-byte, non-zero offsets.
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

    /// Encode failures
    func testEncodeFailures() throws {
        let map = SourceMap()
        map.sources = [.remote(url: "source1.css")]

        map.setSegments([[.init(columns: 0..<8, sourcePos: .some(.init(source: 1, line: 0, column: 0)))]])
        XCTAssertSourceMapError(.invalidSource(1, count: 1)) {
            _ = try map.encode(continueOnError: false)
        }

        map.setSegments([[.init(columns: 0..<8, sourcePos: .some(.init(source: 0, line: 0, column: 0, name: 0)))]])
        XCTAssertSourceMapError(.invalidName(0, count: 0)) {
            _ = try map.encode(continueOnError: false)
        }
    }

    /// Map failures
    func testMapFailures() throws {
        let map = SourceMap()
        map.sources = [.remote(url: "source1.css")]
        map.names = ["name1"]

        map.setSegments([
            // line 0 - empty
            [],
            // line 1 - one seg, non-zero offset, no sourcepos
            [.init(columns: 5...10)],
            // line 2 - three segs, first good, second bad name, third bad source
            [.init(columns:  0..<10, sourcePos: .some(.init(source: 0, line: 0, column: 0, name: 0))),
             .init(columns: 10..<20, sourcePos: .some(.init(source: 0, line: 1, column: 1, name: 1))),
             .init(columns: 20..<30, sourcePos: .some(.init(source: 1, line: 2, column: 2)))
            ]
        ])

        // line out of range
        XCTAssertNil(try map.map(line: 3, column: 0))

        // empty line
        XCTAssertNil(try map.map(line: 0, column: 0))

        // before segs start
        XCTAssertNil(try map.map(line: 1, column: 4))
        XCTAssertNotNil(try map.map(line: 1, column: 5))

        // name error correction
        XCTAssertEqual(0, try map.map(line: 2, column: 8)?.sourcePos?.name)
        let sourcePos = try XCTUnwrap(try map.map(line: 2, column: 10)?.sourcePos)
        XCTAssertNil(sourcePos.name)

        // source error correction
        let segNil = try XCTUnwrap(try map.map(line: 2, column: 20))
        XCTAssertNil(segNil.sourcePos)
        let markerPos = SourceMap.SourcePos(source: 5, line: 5, column: 5)
        let segMarker = try XCTUnwrap(try map.map(line: 2, column: 20, invalidSourcePos: markerPos))
        XCTAssertEqual(markerPos, segMarker.sourcePos)
    }

    /// Misc Segment methods
    func testSegment() throws {
        let seg1 = SourceMap.Segment(columns: 1...4)
        let seg2 = SourceMap.Segment(columns: 1...6)
        XCTAssertEqual(1...4, seg1.columns)
        XCTAssertEqual(1...6, seg2.columns)
        XCTAssertEqual(seg1, seg2)
        var dict = [SourceMap.Segment:Bool]()
        dict[seg1] = true
        XCTAssertTrue(dict[seg2]!)
    }
}
