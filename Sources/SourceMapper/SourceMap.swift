//
//  SourceMap.swift
//  SourceMapper
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//
import Foundation

/// A source map describing how each segment of a generated file corresponds to some original source file.
///
/// The main use cases imagined are:
///  1. Read a source map, make minor modifications, write it back ``encode(...)``.
///  2. Create a new source map ``init(version:)``, fill in fields, and write it ``encode(...)``.
///  3. Read and unpack a source map ``UnpackedSourceMap.init(...)`` and query it ``UnpackedSourceMap.map(...)``.
///
/// There are two representations of the actual mappings.  The ``mappings`` property holds
/// the compacted mapping string that looks like `AAAA;EACA`.   This can be decoded into
/// or written via arrays of ``Segment``s.  These arrays can be very large and time-consuming to create.  The
/// separate ``UnpackedSourceMap`` type works to cache them and satisfy queries.
///
public struct SourceMap: Hashable, Sendable {
    /// Create an empty source map.
    public init(version: Int = SourceMap.VERSION) {
        self.version = version
        file = nil
        sourceRoot = nil
        sources = []
        names = []
        mappings = ""
    }

    /// The expected version - 3 - of source maps.
    public static let VERSION = 3

    /// The spec version that this source map follows.
    public let version: Int

    /// The name of the generated code file with which the source map is associated.
    public var file: String?

    /// Value to prepend to each ``sources`` URL before attempting their resolution.
    public var sourceRoot: String?

    /// The location and content of an original source referred to from the source map.
    ///
    /// Use ``getSourceURL(...)`` to interpret source URLs incorporating ``sourceRoot``.
    public struct Source: Hashable, Sendable {
        /// The URL recorded in the source map for this source.
        ///
        /// See: ``SourceMap.getSourceURL(...)``.
        public let url: String

        /// The content, if any, recorded in the source map for this source.
        public let content: String?

        /// Initialize a new Source.
        public init(url: String, content: String? = nil) {
            self.url = url
            self.content = content
        }
    }

    /// The original sources referred to from the source map.
    public var sources: [Source]

    /// Get the URL of a source, incorporating the ``sourceRoot`` if set.
    ///
    /// - parameter source: The index into ``sources`` to look up.
    /// - parameter sourceMapURL: The absolute URL of this source map -- relative source URLs
    ///   are interpreted relative to this base.
    public func getSourceURL(source: Int, sourceMapURL: URL) -> URL {
        precondition(source < sources.count)
        let sourceURLString = (sourceRoot ?? "") + sources[source].url
        if let sourceURL = URL(string: sourceURLString),
           sourceURL.scheme != nil {
            return sourceURL
        }
        return URL(string: sourceURLString, relativeTo: sourceMapURL)!
    }

    /// Names that can be associated with segments of the generated code.
    public var names: [String]

    /// The source map's mappings in their compacted format.
    ///
    /// Writing to ``segments`` updates this field.
    public var mappings: String

    /// A position in an original source file.  Only has meaning in the context of a ``SourceMap``.
    public struct SourcePos: Hashable, Sendable {
        /// 0-based index into ``SourceMap.sources`` of the original source.
        public let source: Int32
        /// 0-based line index into the original source file.
        public let line: Int32
        /// 0-based column index into line ``line``.
        public let column: Int32
        /// 0-based index into ``SourceMap.names`` of any name associated with
        /// the mapping segment, or `nil` if there is none.
        public let name: Int32?

        /// Initialize a new ``SourcePos``.
        public init(source: Int32,
                    line: Int32,
                    column: Int32,
                    name: Int32? = nil) {
            self.source = source
            self.line = line
            self.column = column
            self.name = name
        }
    }

    /// A decoded segment of the source map.
    ///
    /// This maps a region from a particular generated line (not explicit in this type)
    /// and column range (really just start column) to a source region and optionally a name, or
    /// asserts that range is not related to a source.
    ///
    /// All indices are 0-based.
    public struct Segment: Hashable, Sendable {
        /// 0-based column in the generated code that starts the segment.
        public let firstColumn: Int32

        /// 0-based column in the generated code that ends the segment, or `nil`
        /// indicating 'until either the next segment or the end of the line'.
        ///
        /// This field is optional and advisory - it's not stored in the source map itself, rather
        /// calculated (guessed) from the next ``firstColumn`` value.  Its value is not
        /// used in comparisons between two ``Segment``s.
        public internal(set) var lastColumn: Int32?

        /// The range of columns covered by this segment, or `nil` if not known.
        public var columns: ClosedRange<Int32>? {
            lastColumn.flatMap { firstColumn...$0 }
        }

        /// The original source position associated with the segment, or `nil` if there is none.
        public let sourcePos: SourcePos?

        /// Initialize a segment from column indices.
        public init(firstColumn: Int32, lastColumn: Int32? = nil, sourcePos: SourcePos? = nil) {
            self.firstColumn = firstColumn
            self.lastColumn = lastColumn
            self.sourcePos = sourcePos
        }

        /// Initialize a segment from a ``Range`` of columns.
        public init(columns: Range<Int32>, sourcePos: SourcePos? = nil) {
            self.init(firstColumn: columns.lowerBound,
                      lastColumn: columns.upperBound - 1,
                      sourcePos: sourcePos)
        }

        /// Initialize a segment from a ``ClosedRange`` of columns.
        public init(columns: ClosedRange<Int32>, sourcePos: SourcePos? = nil) {
            self.init(firstColumn: columns.lowerBound,
                      lastColumn: columns.upperBound,
                      sourcePos: sourcePos)
        }

        /// Compare two segments.  The ``lastColumn`` value is not included. :nodoc:
        public static func == (lhs: Segment, rhs: Segment) -> Bool {
            lhs.firstColumn == rhs.firstColumn &&
            lhs.sourcePos == rhs.sourcePos
        }

        /// Hash the segment. :nodoc:
        public func hash(into hasher: inout Hasher) {
            hasher.combine(firstColumn)
            hasher.combine(sourcePos)
        }
    }
}

// MARK: Printers

extension SourceMap.SourcePos: CustomStringConvertible {
    /// A short human-readable description of the position.
    public var description: String {
        "source=\(source) line=\(line) col=\(column)\(name.flatMap { " name=\($0)" } ?? "")"
    }
}

extension SourceMap.Segment: CustomStringConvertible {
    /// A short human-readable description of the segment.
    public var description: String {
        let range = "col=\(firstColumn)\(lastColumn.flatMap { "-\($0)" } ?? "")"
        let content = sourcePos.flatMap { "(\($0))" } ?? "unmapped"
        return "\(range) \(content)"
    }
}

extension SourceMap: CustomStringConvertible {
    /// A short description of the source map.
    public var description: String {
        var str = "SourceMap(v=\(version)"
        if let file = file {
            str += #" file="\#(file)""#
        }
        if let sourceRoot = sourceRoot {
            str += #" sourceRoot="\#(sourceRoot)""#
        }
        str += " #sources=\(sources.count)"
        if names.count > 0 {
            str += " #names=\(names.count)"
        }
        func getMapStr() -> String {
            if mappings.count < 20 {
                return mappings
            }
            return mappings.prefix(17) + "..."
        }
        return #"\#(str) mappings="\#(getMapStr())")"#
    }
}
