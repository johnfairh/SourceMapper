//
//  Errors.swift
//  SourceMapper
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

/// Error conditions detected by the module.
public enum SourceMapError: Error, CustomStringConvertible {
    /// Source map decoding failed because the `format` field's value is invalid.
    case invalidFormat(UInt)

    /// Source map decoding failed because the `sources` and `sourcesContent` fields have different cardinalities.
    case inconsistentSources(sourcesCount: Int, sourcesContentCount: Int)

    /// A short human-readable description of the error
    public var description: String {
        switch self {
        case .invalidFormat(let format):
            return "Invalid value for `format` field: \(format)."
        case .inconsistentSources(let sourcesCount, let sourcesContentCount):
            return "Inconsistent source map, \(sourcesCount) sources[] but \(sourcesContentCount) sourcesContent[]"
        }
    }
}
