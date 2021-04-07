//
//  SourceMap.swift
//  SourceMapper
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//
import Foundation

/// 1 - open a sourcemap, mess around with it a bit, rewrite it,
/// 2 - join multiple sourcemaps together
/// 3 - open a sourcemap and use it, doing location queries including source file locations
/// 4 - create a new sourcemap from scratch and write it to a file.
///
struct SourceMap {
    /// Create an empty source map.
    public init() {
        version = 3
        file = nil
        sourceRoot = nil
        sources = []
        names = []
        mappings = ""
        mappingSegments = nil
        mappingsValid = true
        extensions = [:]
    }

    /// Decode a source map from a JSON string as `Data`.
    public init(data: Data) throws {
        self.init()
    }

    /// Decode a source map from a JSON string.
    ///
    /// - throws: If the JSON is bad, the version is bad, or if mandatory fields are missing.
    ///   The mappings aren't decoded until you access
    public init(string: String) throws {
        try self.init(data: string.data(using: .utf8)!)
    }

    /// The spec version that this source map follows.
    public let version: UInt

    /// The expected version - 3 - of source maps.
    public static let VERSION = UInt(3)

    /// The name of the generated code file with which the source map is associated.
    public var file: String?

    /// Value to prepend to each `sources` url before attempting their resolution.
    public var sourceRoot: String?

    /// The location and content of an original source referred to from the source map.
    /// The full URL of a source is computed by first prepending `sourceRoot`.  If that gives
    /// an absolute URL then use it.  Otherwise resolve it relative to the URL of the source map.
    public enum Source {
        case remote(url: String)
        case inline(url: String, content: String)
    }

    /// The original sources referred to from the source map.
    public var sources: [Source] {
        willSet {
            if newValue.count != sources.count {
                mappingsValid = false
            }
        }
    }

    /// Get the URL of a source, incorporating the `sourceRoot` if set.
    ///
    /// - parameter sourceIndex: The index into `sources` to look up
    /// - parameter sourceMapURL: The URL of this source map -- source URLs are calculated
    ///   relative to this location.
    public func findSourceURL(sourceIndex: Int, sourceMapURL: URL) -> URL? {
        nil
    }

    /// Names that can be associated with segments of the generated code.
    public var names: [String] {
        willSet {
            if newValue.count != names.count {
                mappingsValid = false
            }
        }
    }

    /// A decoded segment of the source map.
    ///
    /// This maps a region from a particular generated line (not explicit in this type)
    /// and start column to some source region and optionally a name.  The generated
    /// end column is not explicit in the type.
    public struct MappingSegment {
        /// 0-based column in the generated code being mapped from.  The mapping lasts
        /// until either the end of the generated line or the `generatedColumnIndex` of
        /// the next mapping segment.
        public let generatedColumnIndex: Int32
        /// 0-based index into `sources` of the segment's original source.
        public let sourceIndex: Int32
        /// 0-based line index into the original source.
        public let sourceLineIndex: Int32
        /// 0-based column index into the `sourceLineIndex`.  The end of the mapping
        /// is not defined.
        public let sourceColumnIndex: Int32
        /// 0-based index into `names` of the name associated with the segment, or `nil`
        /// if there is none.
        public let nameIndex: Int32?
    }

    /// The mappings in their compacted format
    public private(set) var mappings: String

    /// Track consistency between `mappings` and `_mappingSegments`.
    /// If `false` then `mappings` need regenerating.
    private var mappingsValid: Bool

    /// Cache of decoded mapping segments
    private var mappingSegments: [[MappingSegment]]?

    private func unpackMappings() throws -> [[MappingSegment]] {
        []
    }

    /// Value to use in place of a segment mapping that references an invalid source or name index.
    /// By default a `MappingSegment` containing all zero indicies is used.
    public var invalidSegment: MappingSegment? = nil

    /// Debug log of invalid indices found while unpacking mappings.
    public private(set) var invalidSegmentReports: [String] = []

    /// One list of `MappingSegment`s for every line in the generated code file.
    ///
    /// Decodes the mappings if necessary.
    /// - throws: If the mappings are undecodable in some way indicating a corrupt source map.
    ///   No error is thrown for invalid indicies - an `invalidSegment` is substituted and the offence
    ///   reported  in  `invalidSegmentReports`.
    public mutating func getMappingSegments() throws -> [[MappingSegment]] {
        if let segments = mappingSegments {
            return segments
        }
        return try unpackMappings()
    }

    /// Update the mapping segments.  No validation done against `sources` or `names`.
    public mutating func setMappingSegments(_ segments: [[MappingSegment]]) {
        mappingSegments = segments
        mappingsValid = false
    }

    /// Map a location in the generated code to its source.
    ///
    /// - parameter rowIndex: 0-based index of the row in the generated code file.
    /// - parameter columnIndex: 0-based index of the column in `rowIndex`.
    /// - throws: If the mappings can't be decoded.  See `getMappingSegments()`.
    /// - returns: The mapping segment, or `nil` if there is no mapping for the row.
    public mutating func map(rowIndex: Int, columnIndex: Int) throws -> MappingSegment? {
        nil
    }

    /// Extension fields
    public var extensions: [String:Any]

    /// Encode the source map as a JSON string
    ///
    /// - parameter continueOnError: Set the error handling policy.  If `false` then
    ///   any inconsistencies in the mapping data cause an error to be thrown, otherwise they
    ///   are passed through to the JSON format.
    ///
    ///   The default is `true` which is probably right when working with existing sourcemaps,
    ///   but if you're creating from scratch it may be more useful to set `false` to catch bugs
    ///   in your generation code.
    ///
    /// - throws: If `continueOnError` is `false` and there is an error; or if JSON
    ///   encoding fails for some reason.
    public func encoded(continueOnError: Bool = true) throws -> String {
        ""
    }

    /// Append a second source map to this one.
    ///
    /// Used when the corresponding generated code files are appended.
    ///
    /// If your source maps are using `sourceRoot` then you should ideally sync them before
    /// this merge, otherwise the `sources` fields will be updated to include the different values of
    /// `sourceRoot` which will be tougher to unpick later if necessary.
    ///
    /// Extension fields are preserved in the merged source map.
    ///
    /// - parameter sourceMap: The source map to append to this one.
    /// - parameter generatedLineIndex: The 0-based index in the new  generated code file
    ///   where the `sourceMap` should start.
    /// - parameter generatedColumnIndex: The 0-based index in the new generated code file
    ///   where the `sourceMap` should start.
    /// - throws: If both source maps contain the same extension field.
    public mutating func append(sourceMap: SourceMap,
                                generatedLineIndex: Int,
                                generatedColumnIndex: Int) throws {
    }
}
