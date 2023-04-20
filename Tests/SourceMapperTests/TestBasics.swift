//
//  TestBasics.swift
//  SourceMapperTests
//
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
        let files = ["jazzy.css.map.dart", "jazzy.css.map.libsass"]
        try files.forEach { fixtureName in
            let map = try SourceMap(fixtureName: fixtureName)
            XCTAssertEqual(SourceMap.VERSION, map.version)
            let file = try XCTUnwrap(map.file)
            XCTAssertEqual(fixtureName.replacingOccurrences(of: ".map", with: ""), file)
            XCTAssertEqual(1, map.sources.count)
            XCTAssertTrue(map.sources[0].url.hasSuffix("jazzy.css.scss"))

            print(map)
            let unpackedMap = try UnpackedSourceMap(map)
            print(unpackedMap.segmentsDescription)

            // Check a couple of mapping positions, one towards the start and
            // one at the end to check the mapping accumulators.

            let mapped1 = try XCTUnwrap(unpackedMap.map(line: 26, column: 22))
            let pos1 = try XCTUnwrap(mapped1.sourcePos)
            XCTAssertEqual(25, pos1.line)
            XCTAssertTrue(pos1.column >= 14)

            let mapped2 = try XCTUnwrap(unpackedMap.map(line: 465, column: 12))
            let pos2 = try XCTUnwrap(mapped2.sourcePos)
            XCTAssertEqual(601, pos2.line)
            XCTAssertTrue(pos2.column >= 4)
        }
    }

    func testPrinting() throws {
        var map = SourceMap()
        XCTAssertTrue(try UnpackedSourceMap(map).segmentsDescription.isEmpty)
        XCTAssertEqual(#"SourceMap(v=3 #sources=0 mappings="")"#, map.description)

        map.file = "myfile.css"
        map.sourceRoot = "../dist"
        map.sources = [.init(url: "a.scss")]
        map.names = ["fred", "barney"]
        XCTAssertEqual(#"SourceMap(v=3 file="myfile.css" sourceRoot="../dist" #sources=1 #names=2 mappings="")"#, map.description)

        try map.set(segments: [
            [
                .init(columns: 0...12, sourcePos: .some(.init(source: 0, line: 0, column: 0, name: 1))),
                .init(columns: 13...15, sourcePos: .some(.init(source: 0, line: 1, column: 0, name: 1)))
            ]
        ], validate: true)
        let segDesc = try UnpackedSourceMap(map).segmentsDescription
        XCTAssertEqual("""
                       line=0 col=0-12 (source=0 line=0 col=0 name=1)
                              col=13 (source=0 line=1 col=0 name=1)
                       """, segDesc)
        _ = try map.encode() // to encode the mapping string
        print(map.description)
        XCTAssertTrue(map.description.hasSuffix(#" mappings="AAAAC,aACAA")"#))
    }

    func testSourceURL() throws {
        var map = SourceMap()
        map.sources = [.init(url: "http://host/path/a.scss"),
                       .init(url: "../dist/b.scss"),
                       .init(url: "c.scss")]
        let mapURL = URL(fileURLWithPath: "/web/main.map")

        let source1 = map.getSourceURL(source: 0, sourceMapURL: mapURL)
        XCTAssertEqual("http://host/path/a.scss", source1.absoluteString)

        let source2 = map.getSourceURL(source: 1, sourceMapURL: mapURL)
        XCTAssertEqual("file:///dist/b.scss", source2.absoluteString)

        map.sourceRoot = "./../dist/"
        let source3 = map.getSourceURL(source: 2, sourceMapURL: mapURL)
        XCTAssertEqual("file:///dist/c.scss", source3.absoluteString)
    }
}
