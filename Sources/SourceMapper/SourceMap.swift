//
//  SourceMap.swift
//  SourceMapper
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//
import Foundation

/// Don't support extension fields ("x_|whatever|"): nobody seems to use them, even the one in the spec
/// seems unknown today, and it immensely complicates the JSON layer.
///
/// 1 - open a sourcemap, mess around with it a bit, rewrite it,
/// 2 - join multiple sourcemaps together
/// 3 - open a sourcemap and use it, doing location queries including source file locations
/// 4 - create a new sourcemap from scratch and write it to a file.
///
public final class SourceMap {
    /// Create an empty source map.
    public init(version: UInt = SourceMap.VERSION) {
        self.version = version
        file = nil
        sourceRoot = nil
        sources = []
        names = []
        mappings = ""
        mappingSegments = nil
        mappingsValid = true
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
    ///
    /// Use `getSourceURL(...)`to interpret source URLs incorporating `sourceRoot`.
    public enum Source {
        case remote(url: String)
        case inline(url: String, content: String)

        /// The URL recorded in the source map for this source.
        /// - see: `SourceMap.getSourceURL(...)`.
        public var url: String {
            switch self {
            case .remote(let url),
                 .inline(let url, _): return url
            }
        }

        /// The content, if any, recorded in the source map for this source.
        public var content: String? {
            switch self {
            case .remote: return nil
            case .inline(_, let content): return content
            }
        }
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
    /// - parameter sourceIndex: The index into `sources` to look up.
    /// - parameter sourceMapURL: The URL of this source map -- source URLs are calculated
    ///   relative to this location.
    public func getSourceURL(sourceIndex: Int, sourceMapURL: URL) -> URL {
        URL(fileURLWithPath: "/")
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
    public internal(set) var mappings: String

    /// Track consistency between `mappings` and `_mappingSegments`.
    /// If `false` then `mappings` need regenerating.
    internal var mappingsValid: Bool

    /// Cache of decoded mapping segments
    internal var mappingSegments: [[MappingSegment]]?

    /// Value to use in place of a segment mapping that references an invalid source or name index.
    /// By default a `MappingSegment` containing all zero indicies is used.
    public var invalidSegment: MappingSegment? = nil

    /// Debug log of invalid indices found while unpacking mappings.
    public private(set) var invalidSegmentReports: [String] = []

    /// Append a second source map to this one.
    ///
    /// Used when the corresponding generated code files are appended.
    ///
    /// If your source maps are using `sourceRoot` then you should ideally sync them before
    /// this merge, otherwise the `sources` fields will be updated to include the different values of
    /// `sourceRoot` which will be tougher to unpick later if necessary.
    ///
    /// - parameter sourceMap: The source map to append to this one.
    /// - parameter generatedLineIndex: The 0-based index in the new  generated code file
    ///   where the `sourceMap` should start.
    /// - parameter generatedColumnIndex: The 0-based index in the new generated code file
    ///   where the `sourceMap` should start.
    /// - throws: ???
    public func append(sourceMap: SourceMap,
                       generatedLineIndex: Int,
                       generatedColumnIndex: Int) throws {
    }
}
