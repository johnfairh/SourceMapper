//
//  Mappings.swift
//  SourceMapper
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

import Foundation

extension SourceMap {
    /// One list of `Segment`s for every line in the generated code file.
    ///
    /// Decodes the mappings if necessary.
    /// - throws: If the mappings are undecodable in some way indicating a corrupt source map.
    ///   No error is thrown for invalid indicies - an `invalidSegment` is substituted and the offence
    ///   reported  in  `invalidSegmentReports`.
    public func getSegments() throws -> [[Segment]] {
        if let segments = segments {
            return segments
        }
        let newSegments = try unpackMappings()
        segments = newSegments
        return newSegments
    }

    /// Update the mapping segments.  No validation done against `sources` or `names`.
    public func setSegments(_ segments: [[Segment]]) {
        self.segments = segments
        mappingsValid = false
    }

    /// Unpack the `mappings` string
    func unpackMappings() throws -> [[Segment]] {
        var source = Int32(0)
        var sourceLine = Int32(0)
        var sourceColumn = Int32(0)
        var name = Int32(0)

        return try mappings.split(separator: ";", omittingEmptySubsequences: false).map { line in
            var generatedColumn = Int32(0)
            return try line.split(separator: ",").map { seg in
                let numbers = try VLQ.decode(seg)
                let seg: Segment
                switch numbers.count {
                case 1:
                    seg = Segment(firstColumn: generatedColumn + numbers[0])
                case 4...5:
                    let name = (numbers.count == 5) ? (name + numbers[4]) : nil
                    let pos = SourcePos(source: source + numbers[1],
                                        line: sourceLine + numbers[2],
                                        column: sourceColumn + numbers[3],
                                        name: name)
                    seg = Segment(firstColumn: generatedColumn + numbers[0],
                                  sourcePos: pos)
                default:
                    // throw badness
                    preconditionFailure()
                }

                generatedColumn = seg.firstColumn
                seg.sourcePos.flatMap { pos in
                    source = pos.source
                    sourceLine = pos.line
                    sourceColumn = pos.column
                    pos.name.flatMap { name = $0 }
                }
                return seg
            }
        }
    }

    func updateMappings(continueOnError: Bool) throws {
        precondition(!mappingsValid)
        mappingsValid = true
    }

    /// Map a location in the generated code to its source.
    ///
    /// - parameter rowIndex: 0-based index of the row in the generated code file.
    /// - parameter columnIndex: 0-based index of the column in `rowIndex`.
    /// - throws: If the mappings can't be decoded.  See `getMappingSegments()`.
    /// - returns: The mapping segment, or `nil` if there is no mapping for the row.
    public func map(row: Int, column: Int) throws -> Segment? {
        let segs = try getSegments()
        guard row < segs.count else {
            return nil
        }
        let rowSegs = segs[row]
        switch rowSegs.count {
        case 0: return nil
        case 1: return rowSegs[0]
        default:
            if column < rowSegs[0].firstColumn {
                return nil
            }
            // xxx should binary search but in practice not a lot of entries....
            for n in 0 ..< rowSegs.count {
                if column < rowSegs[n].firstColumn {
                    return rowSegs[n - 1]
                }
            }
            return rowSegs.last
        }
    }
}
