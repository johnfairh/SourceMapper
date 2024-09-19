//
//  TestVLQ.swift
//  SourceMapperTests
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

@testable import SourceMapper
import Testing

extension Tag {
    @Tag static var vlq: Self
}


@Suite(.tags(.vlq))
final class TestVLQ {
    // base64 first

    @Test(arguments: ["A", "F", "z", "j", "4", "9", "+", "/"])
    func testBase64(string: String) throws {
        let char = string.first!
        let val = try Base64.shared.decode(char)
        let nc = Base64.shared.encode(val)
        #expect(char == nc)
    }

    @Test(arguments: [
        ".",
        "ä"
    ])
    func testBadBase64(string: String) {
        let char = string.first!
        #expect(throws: SourceMapError.invalidBase64Character(char)) {
            let val = try Base64.shared.decode(char)
            Issue.record("Managed to decode \(char): \(val)")
        }
    }

    // vlq

    @Test(arguments: [0, -1, 1, 0xf, 0x10, 0x7f, -0x1000, Int32.max, Int32.min])
    func testVLQSingle(value: Int32) throws {
        let i32 = Int32(value)
        let encoded = VLQ.encode(i32)
        let decoded = try VLQ.decode(encoded)
        try #require(1 == decoded.count)
        #expect(i32 == decoded[0])
    }

    @Test
    func testVLQList() throws {
        let data = [1, -1, Int32.max, 29473401, Int32.min]
        let encoded = VLQ.encode(data)
        let decoded = try VLQ.decode(encoded)
        #expect(data == decoded)
    }

    @Test(arguments: [
        "w",
        "wwwwwwwwwwwwww"
    ])
    func testBadVLQ(vlq: String) {
        #expect(throws: SourceMapError.invalidVLQStringUnterminated(vlq: vlq, soFar: [])) {
            let decoded = try VLQ.decode(vlq)
            print("Managed to decode bad string: \(decoded)")
        }
    }
}
