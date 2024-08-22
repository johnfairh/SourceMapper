//
//  TestBasics.swift
//  SourceMapperTests
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

@testable import SourceMapper
import Testing
import Foundation

extension Tag {
    @Tag static var basics: Self
}

/// Basic flows of the use cases
@Suite(.tags(.basics))
final class TestBasics {
    @Test
    func testEmptyRoundTrip() throws {
        let empty = SourceMap()
        let serialized = try empty.encode()
        let deserialized = try SourceMap(serialized)
        #expect(empty == deserialized)
        #expect(try empty.encodeString() == deserialized.encodeString())
    }

    @Test(arguments: ["jazzy.css.map.dart", "jazzy.css.map.libsass"])
    func testLoading(fixtureName: String) throws {
        let map = try SourceMap(fixtureName: fixtureName)
        #expect(map.version == SourceMap.VERSION)
        let file = try #require(map.file)
        #expect(file == fixtureName.replacingOccurrences(of: ".map", with: ""))
        #expect(map.sources.count == 1)
        #expect(map.sources[0].url.hasSuffix("jazzy.css.scss"))

        print(map)
        let unpackedMap = try UnpackedSourceMap(map)
        print(unpackedMap.segmentsDescription)

        // Check a couple of mapping positions, one towards the start and
        // one at the end to check the mapping accumulators.

        let mapped1 = try #require(unpackedMap.map(line: 26, column: 22))
        let pos1 = try #require(mapped1.sourcePos)
        #expect(pos1.line == 25)
        #expect(pos1.column >= 14)

        let mapped2 = try #require(unpackedMap.map(line: 465, column: 12))
        let pos2 = try #require(mapped2.sourcePos)
        #expect(pos2.line == 601)
        #expect(pos2.column >= 4)
    }

    @Test
    func testPrinting() throws {
        var map = SourceMap()
        try #expect(UnpackedSourceMap(map).segmentsDescription.isEmpty)
        #expect(map.description == #"SourceMap(v=3 #sources=0 mappings="")"#)

        map.file = "myfile.css"
        map.sourceRoot = "../dist"
        map.sources = [.init(url: "a.scss")]
        map.names = ["fred", "barney"]
        #expect(map.description == #"SourceMap(v=3 file="myfile.css" sourceRoot="../dist" #sources=1 #names=2 mappings="")"#)

        try map.set(segments: [
            [
                .init(columns: 0...12, sourcePos: .some(.init(source: 0, line: 0, column: 0, name: 1))),
                .init(columns: 13...15, sourcePos: .some(.init(source: 0, line: 1, column: 0, name: 1)))
            ]
        ])
        let segDesc = try UnpackedSourceMap(map).segmentsDescription
        #expect(segDesc == """
                           line=0 col=0-12 (source=0 line=0 col=0 name=1)
                                  col=13 (source=0 line=1 col=0 name=1)
                           """)
        _ = try map.encode() // to encode the mapping string
        print(map.description)
        #expect(map.description.hasSuffix(#" mappings="AAAAC,aACAA")"#))
    }

    @Test
    func testSourceURL() throws {
        var map = SourceMap()
        map.sources = [.init(url: "http://host/path/a.scss"),
                       .init(url: "../dist/b.scss"),
                       .init(url: "c.scss")]
        let mapURL = URL(fileURLWithPath: "/web/main.map")

        let source1 = map.getSourceURL(source: 0, sourceMapURL: mapURL)
        #expect(source1.absoluteString == "http://host/path/a.scss")

        let source2 = map.getSourceURL(source: 1, sourceMapURL: mapURL)
        #expect(source2.absoluteString == "file:///dist/b.scss")

        map.sourceRoot = "./../dist/"
        let source3 = map.getSourceURL(source: 2, sourceMapURL: mapURL)
        #expect(source3.absoluteString == "file:///dist/c.scss")
    }
}
