//
//  Errors.swift
//  SourceMapper
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

/// Error conditions detected by the module.
public enum SourceMapError: Error, CustomStringConvertible, Equatable {
    /// Source map decoding failed because the `format` field's value is invalid.
    case invalidFormat(Int)

    /// Source map decoding failed because the `sources` and `sourcesContent` fields have different cardinalities.
    case inconsistentSources(sourcesCount: Int, sourcesContentCount: Int)

    /// Source map decoding failed because of an invalid character in the `mappings` field.
    case invalidBase64Character(Character)

    /// Source map decoding failed because a VLQ sequence does not terminate properly.
    case invalidVLQStringUnterminated(vlq: String, soFar: [Int32])

    /// Source map decoding failed because a VLQ sequence has the wrong number of entries.
    case invalidVLQStringLength([Int32])

    /// Source map encoding failed because a source index is out of range.
    case invalidSource(Int, count: Int)

    /// Source map encoding failed because a name index is out of range.
    case invalidName(Int, count: Int)

    /// A short human-readable description of the error.
    public var description: String {
        switch self {
        case .invalidFormat(let format):
            return "Invalid value for `format` field: \(format)"
        case .inconsistentSources(let sourcesCount, let sourcesContentCount):
            return "Inconsistent source map, \(sourcesCount) sources[] but \(sourcesContentCount) sourcesContent[]"
        case .invalidBase64Character(let character):
            return "Invalid Base64 character in `mappings`: \(character)"
        case .invalidVLQStringUnterminated(let vlq, let soFar):
            return "Invalid VLQ string '\(vlq)' - got \(soFar) before failure"
        case .invalidVLQStringLength(let decoded):
            return "Invalid mapping segment, bad number of entries: \(decoded)"
        case .invalidSource(let source, let count):
            return "Invalid source index \(source), source count \(count)"
        case .invalidName(let name, let count):
            return "Invalid name index \(name), name count \(count)"
        }
    }
}
