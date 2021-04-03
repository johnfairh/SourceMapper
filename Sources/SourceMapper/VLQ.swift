//
//  VLQ.swift
//  SourceMapper
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

// TODO where to put these
struct BadBase64CharacterError: Error, CustomStringConvertible {
    let description: String
    init(_ char: Character) {
        description = "Can't decode as base64 character: \(char)"
    }
}

struct BadVLQStringError: Error, CustomStringConvertible {
    let vlq: String
    let soFar: [Int32]

    init(vlq: String = "", soFar: [Int32] = []) {
        self.vlq = vlq
        self.soFar = soFar
    }

    var description: String {
        "Can't decode VLQ string '\(vlq)' - got \(soFar) before failure"
    }
}

/// Utilities for working with VLQs.
///
/// Each segment of mapping data is a variable-length list of Int32s, VLQ Base64 encoded.
/// Each Int32 is transformed into a sequence of 6-bit records, then each record is Base64'd
/// The first record of an Int32 uses LSB as a sign bit (1=negative) then the first 4 bits of the Int32,
/// then the 6th bit as a continuation (1=keep going).  Subsequent records have the next 5 bits of
/// the Int32 and a a continuation bit.
///
/// It seems better to implement the encode this way, rather than packing the 6-bit records into [UInt8]
/// and then using some Base64 library on that.
///
/// Decoding is more painful but again it seems better to process each Base64-encoded record at a time,
/// rather than decode the whole lot and then unpick the 6-bit records -- especially given the quantities
/// are low (max 5 Int32s, typically 1, typically 1-2 records per).
///
/// No base64 padding; Int32s being encoded do not span base64 characters / records.
///
/// Spec says only 32-bit quantities are expected.
///
/// This hasn't been optimized at all.
enum VLQ {
    /// Encode a single number as a Base64 VLQ
    /// XXX is this private?
    static func encode(_ int: Int32) -> String {
        var value = int.magnitude
        var sixBits = [UInt8]()

        var prevFiveBit = UInt8((value & 0x0f) << 1) | (int < 0 ? 1 : 0)
        value >>= 4
        while value != 0 {
            sixBits.append(prevFiveBit | 0x20)
            prevFiveBit = UInt8(value & 0x1f)
            value >>= 5
        }
        sixBits.append(prevFiveBit)
        return String(sixBits.map { Base64.shared.encode($0) })
    }

    /// Encode a list of numbers as Base64 VLQs
    static func encode<S: Sequence>(_ ints: S) -> String where S.Element == Int32 {
        ints.map { encode($0) }.joined()
    }

    /// Progressive decoder of VLQ Base64 values
    private struct Decoder {
        private enum State {
            case idle
            case busy(sign: Bool, cur: Int64, shift: Int)
        }
        private var state: State

        init() {
            state = .idle
        }

        var isIdle: Bool {
            switch state {
            case .idle: return true
            case .busy: return false
            }
        }

        mutating func decode(base64char: Character) throws -> Int32? {
            let sixBit: UInt8 = try Base64.shared.decode(base64char)
            let fiveBit = Int64(sixBit & 0x1f)
            let continuation = (sixBit & 0x20) != 0

            switch state {
            case .idle:
                let sign = (sixBit & 1) != 0
                // Fastpath
                if !continuation {
                    return Int32((fiveBit >> 1) * (sign ? -1 : 1))
                }
                state = .busy(sign: sign, cur: Int64(fiveBit >> 1), shift: 4)

            case .busy(sign: let sign, cur: let cur, shift: let shift):
                let new = cur | (fiveBit << shift)
                if new > Int64(Int32.max) + 1 {
                    throw BadVLQStringError()
                }
                if !continuation {
                    state = .idle
                    return Int32(new * (sign ? -1 : 1))
                }
                state = .busy(sign: sign, cur: new, shift: shift + 5)
            }
            return nil
        }
    }

    /// Decode a Base64 VLQ string into a list of numbers.
    static func decode(_ vlq: String) throws -> [Int32] {
        var decoder = Decoder()
        var output = [Int32]()
        do {
            try vlq.forEach {
                if let value = try decoder.decode(base64char: $0) {
                    output.append(value)
                }
            }
        } catch {
        }
        if !decoder.isIdle {
            throw BadVLQStringError(vlq: vlq, soFar: output)
        }
        return output
    }
}

/// Base64 utilities
///
/// Working on single units at a time - see header for why.
/// SIngleton - access through `Base64.shared`.
///
/// my guess is that doing these in code will actually be more efficient
/// than the lookup tables because of icache/dache.
struct Base64 {
    private let encode: [Character] // index UInt6
    private let decode: [UInt8] // index ascii
    private static let INVALID = UInt8(0xff)

    private init() {
        func toArray(_ range: ClosedRange<Character>) -> [Character] {
            let lowerAscii = range.lowerBound.asciiValue!
            let upperAscii = range.upperBound.asciiValue!
            return (lowerAscii...upperAscii).map { Character(Unicode.Scalar($0)) }
        }
        let encode = toArray("A"..."Z") + toArray("a"..."z") + toArray("0"..."9") + ["+", "/"]
        var decode = Array<UInt8>(repeating: Base64.INVALID, count: 256)
        encode.enumerated().forEach { elem in
            decode[Int(elem.element.asciiValue!)] = UInt8(elem.offset)
        }
        self.encode = encode
        self.decode = decode
    }

    /// Encode a six-bit record.  Will crash on invalid input.
    func encode(_ sixBit: UInt8) -> Character {
        encode[Int(sixBit)]
    }

    /// Decode a character.  Throws something if the character is no good.
    func decode(_ char: Character) throws -> UInt8 {
        guard let asciiVal = char.asciiValue,
              case let decoded = decode[Int(asciiVal)],
              decoded != Base64.INVALID else {
            throw BadBase64CharacterError(char)
        }
        return decoded
    }

    static let shared = Base64()
}
