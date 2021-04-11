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
    case invalidFormat(UInt)

    /// Source map decoding failed because the `sources` and `sourcesContent` fields have different cardinalities.
    case inconsistentSources(sourcesCount: Int, sourcesContentCount: Int)

    /// Source map decoding failed because of a bad character in the `mappings` field.
    case badBase64Character(Character)

    /// Source map decoding failed because a VLQ sequence did not terminate properly.
    case badVLQString(vlq: String, soFar: [Int32])

    /// A short human-readable description of the error
    public var description: String {
        switch self {
        case .invalidFormat(let format):
            return "Invalid value for `format` field: \(format)"
        case .inconsistentSources(let sourcesCount, let sourcesContentCount):
            return "Inconsistent source map, \(sourcesCount) sources[] but \(sourcesContentCount) sourcesContent[]"
        case .badBase64Character(let character):
            return "Invalid Base64 character in `mappings`: \(character)"
        case .badVLQString(let vlq, let soFar):
            return "Invalid VLQ string '\(vlq)' - got \(soFar) before failure"
        }
    }
}
