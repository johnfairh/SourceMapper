//
//  TestVLQ.swift
//  SourceMapperTests
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

@testable import SourceMapper
import XCTest

class TestVLQ: XCTestCase {
    // base64 first

    func testBase64() throws {
        try ["A", "F", "z", "j", "4", "9", "+", "/"].forEach { s in
            let c = s.first!
            let val = try Base64.shared.decode(c)
            let nc = Base64.shared.encode(val)
            XCTAssertEqual(c, nc)
        }
    }

    func testBadBase64() {
        [".", "ä"].forEach { s in
            do {
                let val = try Base64.shared.decode(s.first!)
                XCTFail("Managed to decode \(s): \(val)")
            } catch let error as BadBase64CharacterError {
                print(error)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // vlq

    func testVLQSingle() throws {
        try [0, -1, 1, 0xf, 0x10, 0x7f, -0x1000, Int32.max, Int32.min].forEach {
            let i32 = Int32($0)
            let encoded = VLQ.encode(i32)
            let decoded = try VLQ.decode(encoded)
            XCTAssertEqual(1, decoded.count)
            XCTAssertEqual(i32, decoded[0])
        }
    }

    func testVLQList() throws {
        let data = [1, -1, Int32.max, 29473401, Int32.min]
        let encoded = VLQ.encode(data)
        let decoded = try VLQ.decode(encoded)
        XCTAssertEqual(data, decoded)
    }
}
