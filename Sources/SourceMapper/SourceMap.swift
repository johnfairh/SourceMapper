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
    public init(version: Int = SourceMap.VERSION) {
        self.version = version
        file = nil
        sourceRoot = nil
        sources = []
        names = []
        mappings = ""
        segments = nil
        mappingsValid = true
    }

    /// The spec version that this source map follows.
    public let version: Int

    /// The expected version - 3 - of source maps.
    public static let VERSION = 3

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
    /// - parameter sourceMapURL: The absolute URL of this source map -- relative source URLs
    ///   are interpreted relative to this base.
    public func getSourceURL(sourceIndex: Int, sourceMapURL: URL) -> URL {
        precondition(sourceIndex < sources.count)
        let sourceURLString = (sourceRoot ?? "") + sources[sourceIndex].url
        if let sourceURL = URL(string: sourceURLString),
           sourceURL.scheme != nil {
            return sourceURL
        }
        return URL(string: sourceURLString, relativeTo: sourceMapURL)!
    }

    /// Names that can be associated with segments of the generated code.
    public var names: [String] {
        willSet {
            if newValue.count != names.count {
                mappingsValid = false
            }
        }
    }

    /// A position in an original source file.  Only has meaning in the context of a `SourceMap`.
    public struct SourcePos: Hashable {
        /// 0-based index into `SourceMap.sources` of the original source.
        public let source: Int32
        /// 0-based line index into the original source file.
        public let line: Int32
        /// 0-based column index into line `lineIndex`.
        public let column: Int32
        /// 0-based index into `SourceMap.names` of any name associated with
        /// the mapping segment, or `nil` if there is none.
        public let name: Int32?

        /// Initialize a new `SourcePos`.
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
    public struct Segment: Hashable {
        /// 0-based column in the generated code that starts the segment.
        public let firstColumn: Int32

        /// 0-based column in the generated code that ends the segment, or `nil`
        /// indicating 'until either the next segment or the end of the line'.
        ///
        /// This field is optional and advisory - it's not stored in the sourcemap itself, rather
        /// calculated (guessed) from the next `firstColumn` value.  Its value is not
        /// used in comparisons between two `Segment`s.
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

        /// Initialize a segment from a `Range` of columns.
        public init(columns: Range<Int32>, sourcePos: SourcePos? = nil) {
            self.init(firstColumn: columns.lowerBound,
                      lastColumn: columns.upperBound - 1,
                      sourcePos: sourcePos)
        }

        /// Initialize a segment from a `ClosedRange` of columns.
        public init(columns: ClosedRange<Int32>, sourcePos: SourcePos? = nil) {
            self.init(firstColumn: columns.lowerBound,
                      lastColumn: columns.upperBound,
                      sourcePos: sourcePos)
        }

        /// Compare two segments.  The `lastColumn` value is not included.
        public static func == (lhs: Segment, rhs: Segment) -> Bool {
            lhs.firstColumn == rhs.firstColumn &&
                lhs.sourcePos == rhs.sourcePos
        }

        /// Hash the segment.
        public func hash(into hasher: inout Hasher) {
            hasher.combine(firstColumn)
            hasher.combine(sourcePos)
        }
    }

    /// The mappings in their compacted format
    public internal(set) var mappings: String

    /// Track consistency between `mappings` and `_mappingSegments`.
    /// If `false` then `mappings` need regenerating.
    internal var mappingsValid: Bool

    /// Cache of decoded mapping segments
    internal var segments: [[Segment]]?
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

extension SourceMap {
    /// A formatted multi-line string describing the mapping segments.
    ///
    /// - throws: something if the mapping segments can't be decoded from the source.
    public func getSegmentsDescription() throws -> String {
        var line = 0
        var lines: [String] = []
        try getSegments().forEach {
            let lineIntro = "line=\(line) "
            let introLen = lineIntro.count
            let introPad = String(repeating: " ", count: introLen)
            var intro = lineIntro
            line += 1
            if $0.count == 0 {
                lines.append(intro)
            } else {
                $0.forEach {
                    lines.append("\(intro)\($0)")
                    intro = introPad
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

extension SourceMap: CustomStringConvertible {
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
            guard mappingsValid else { return "???" }
            if mappings.count < 20 {
                return mappings
            }
            return mappings.prefix(17) + "..."
        }
        return #"\#(str) mappings="\#(getMapStr())")"#
    }
}
