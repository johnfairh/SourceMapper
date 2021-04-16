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
        segments = nil
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

    /// A position in an original source file.  Only has meaning in the context of a `SourceMap`.
    public struct SourcePos {
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
    public struct Segment {
        /// 0-based column in the generated code that starts the segment.
        public let firstColumn: Int32

        /// 0-based column in the generated code that ends the segment, or `nil`
        /// indicating 'until either the next segment or the end of the line'.
        public let lastColumn: Int32?

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
    }

    /// The mappings in their compacted format
    public internal(set) var mappings: String

    /// Track consistency between `mappings` and `_mappingSegments`.
    /// If `false` then `mappings` need regenerating.
    internal var mappingsValid: Bool

    /// Cache of decoded mapping segments
    internal var segments: [[Segment]]?

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

extension Sequence where Element: Collection, Element.Element == SourceMap.Segment {
    /// A formatted multi-line string describing the mappings.
    /// XXX rework as SourceMap method?
    public var mappingsDescription: String {
        var line = 0
        var lines: [String] = []
        forEach {
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
