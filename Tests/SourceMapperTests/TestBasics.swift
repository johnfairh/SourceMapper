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

            print(map)
            print(try map.getSegmentsDescription())

            // Check a couple of mapping positions, one towards the start and
            // one at the end to check the mapping accumulators.

            // stubborn libsass...
            let rows: [Int]
            if fixtureName.contains("dart") {
                rows = [30, 510]
            } else {
                rows = [26, 465]
            }

            let mapped1 = try XCTUnwrap(try map.map(line: rows[0], column: 22))
            let pos1 = try XCTUnwrap(mapped1.sourcePos)
            XCTAssertEqual(25, pos1.line)
            XCTAssertTrue(pos1.column >= 14)

            let mapped2 = try XCTUnwrap(try map.map(line: rows[1], column: 12))
            let pos2 = try XCTUnwrap(mapped2.sourcePos)
            XCTAssertEqual(601, pos2.line)
            XCTAssertTrue(pos2.column >= 4)
        }
    }

    func testPrinting() throws {
        let map = SourceMap()
        XCTAssertTrue(try map.getSegmentsDescription().isEmpty)
        XCTAssertEqual(#"SourceMap(v=3 #sources=0 mappings="")"#, map.description)

        map.file = "myfile.css"
        map.sourceRoot = "../dist"
        map.sources = [.remote(url: "a.scss")]
        map.names = ["fred", "barney"]
        XCTAssertEqual(#"SourceMap(v=3 file="myfile.css" sourceRoot="../dist" #sources=1 #names=2 mappings="???")"#, map.description)

        map.segments = [[.init(columns: 0...12, sourcePos: .some(.init(source: 0, line: 0, column: 0, name: 1)))]]
        let segDesc = try map.getSegmentsDescription()
        XCTAssertEqual(#"line=0 col=0-12 (source=0 line=0 col=0 name=1)"#, segDesc)
        _ = try map.encode() // to encode the mapping string
        XCTAssertTrue(map.description.hasSuffix(#" mappings="AAAAC")"#))
    }
}

extension SourceMap.Source {
    var url: String {
        switch self {
        case .inline(let url, _), .remote(let url): return url
        }
    }
}
