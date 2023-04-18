//
//  UnpackedSourceMap.swift
//  SourceMapper
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

import Foundation

// MARK: UnpackedSourceMap

/// A source map that supports efficient mapping queries.
///
/// This bundles together a `SourceMap` and a cache of its unpacked mapping segments.
public struct UnpackedSourceMap: Sendable {
    /// The base source map
    public let sourceMap: SourceMap
    /// The expanded mapping data from `sourceMap`
    public let segments: [[SourceMap.Segment]]

    /// Unpack a new source map
    public init(_ sourceMap: SourceMap) throws {
        self.sourceMap = sourceMap
        self.segments = try sourceMap.segments
    }

    /// Map a location in the generated code to its source.
    ///
    /// All `name` indices are guaranteed valid at time of call: any out of range are replaced with
    /// `nil` before being returned.  All `source` indices are either valid at time of call or as
    /// requested via the `invalidSourcePos` parameter.
    ///
    /// - parameter line: 0-based index of the line in the generated code file.
    /// - parameter column: 0-based index of the column in `rowIndex`.
    /// - parameter invalidSourcePos: Value to substitute for any decoded `SourcePos`
    ///     that is invalid, ie. refers to a `source` that is out of range.  Default `nil`.
    /// - returns: The mapping segment, or `nil` if there is no mapping for the row.
    public func map(line: Int, column: Int, invalidSourcePos: SourceMap.SourcePos? = nil) -> SourceMap.Segment? {
        guard line < segments.count else {
            return nil
        }
        let rowSegs = segments[line]

        func findSegment() -> SourceMap.Segment? {
            guard rowSegs.count > 0 else {
                return nil
            }
            guard column >= rowSegs[0].firstColumn else {
                return nil
            }
            // Could binary search but in practice not a lot of entries,
            // provided we fix the libsass coalescing bug.
            for n in 0 ..< rowSegs.count {
                if column < rowSegs[n].firstColumn {
                    return rowSegs[n - 1]
                }
            }
            return rowSegs.last
        }

        guard var segment = findSegment() else {
            return nil
        }

        if let name = segment.sourcePos?.name,
           name >= sourceMap.names.count {
            segment = segment.withoutSourceName
        }

        guard let sourcePos = segment.sourcePos else {
            return segment
        }

        guard sourcePos.source < sourceMap.sources.count else {
            return segment.with(sourcePos: invalidSourcePos)
        }
        return segment
    }

    /// A formatted multi-line string describing the mapping segments.
    public var segmentsDescription: String {
        var line = 0
        var lines: [String] = []
        segments.forEach {
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
