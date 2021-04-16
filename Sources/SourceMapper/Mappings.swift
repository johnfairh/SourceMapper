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
    private func unpackMappings() throws -> [[Segment]] {
        var source = Int32(0)
        var sourceLine = Int32(0)
        var sourceColumn = Int32(0)
        var name = Int32(0)

        return try mappings.split(separator: ";", omittingEmptySubsequences: false).map { line in
            var generatedColumn = Int32(0)
            return try line.split(separator: ",").map {
                let numbers = try VLQ.decode($0)
                let seg: Segment

                func makeSeg(name: Int32? = nil) -> Segment {
                    let pos = SourcePos(source: source + numbers[1],
                                        line: sourceLine + numbers[2],
                                        column: sourceColumn + numbers[3],
                                        name: name)
                    return Segment(firstColumn: generatedColumn + numbers[0],
                                   sourcePos: pos)
                }

                switch numbers.count {
                case 1:
                    seg = Segment(firstColumn: generatedColumn + numbers[0])
                case 4:
                    seg = makeSeg()
                case 5:
                    name += numbers[4]
                    seg = makeSeg(name: name)
                default:
                    throw SourceMapError.invalidVLQStringLength(numbers)
                }

                generatedColumn = seg.firstColumn
                seg.sourcePos.flatMap { pos in
                    source = pos.source
                    sourceLine = pos.line
                    sourceColumn = pos.column
                }
                return seg
            }
        }
    }


    func updateMappings(continueOnError: Bool) throws {
        var counters = [Int32](repeating: 0, count: 5)

        // interview question: name this routine.
        func updateCountersFindDelta(segValues: [Int32]) -> [Int32] {
            segValues.enumerated().map { (n, value) in
                let newValue = value - counters[n]
                counters[n] = value
                return newValue
            }
        }

        precondition(!mappingsValid)
        let lineStrings = try getSegments().map { line -> String in
            counters[0] = 0
            return try line.map { segment in
                if !continueOnError {
                    try segment.sourcePos?.check(sourceCount: sources.count, namesCount: names.count)
                }
                let delta = updateCountersFindDelta(segValues: segment.values)
                return VLQ.encode(delta)
            }.joined(separator: ",")
        }

        mappings = lineStrings.joined(separator: ";")
        mappingsValid = true
    }

    /// Map a location in the generated code to its source.
    ///
    /// All `name` indicies are guaranteed valid at time of call, any out of range are replaced with
    /// `nil` before being returned.  All `source` indices are either valid at time of call or as
    /// requested via the `invalidSourcePos` parameter.
    ///
    /// - parameter line: 0-based index of the line in the generated code file.
    /// - parameter column: 0-based index of the column in `rowIndex`.
    /// - parameter invalidSourcePos: value to substitute for any decoded `SourcePos`
    ///     that is invalid, ie. refers to a `source` that is out of range.  Default `nil`.
    /// - throws: If the mappings can't be decoded.  See `getSegments()`.
    /// - returns: The mapping segment, or `nil` if there is no mapping for the row.
    public func map(line: Int, column: Int, invalidSourcePos: SourcePos? = nil) throws -> Segment? {
        let segs = try getSegments()
        guard line < segs.count else {
            return nil
        }
        let rowSegs = segs[line]

        func findSegment() -> Segment? {
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
           name >= names.count {
            segment = segment.withoutSourceName
        }

        if let sourcePos = segment.sourcePos,
           sourcePos.source < sources.count {
            return segment
        }

        return segment.with(sourcePos: invalidSourcePos)
    }
}

extension SourceMap.SourcePos {
    /// Version of this pos with any `name` erased
    var withoutName: Self {
        Self(source: source, line: line, column: column)
    }

    /// The list of numbers making up the pos part of the segment, in sourcemap spec order
    var values: [Int32] {
        var arr = [source, line, column]
        if let name = name {
            arr.append(name)
        }
        return arr
    }

    /// Validate `source` and `name` are in range
    func check(sourceCount: Int, namesCount: Int) throws {
        if source >= sourceCount {
            preconditionFailure()
        }
        if let name = name, name >= namesCount {
            preconditionFailure()
        }
    }
}

extension SourceMap.Segment {
    /// Version of this segment with any `sourcePos.name` erased
    var withoutSourceName: Self {
        with(sourcePos: sourcePos?.withoutName)
    }

    /// Version of this segment with `sourcePos` replaced
    func with(sourcePos: SourceMap.SourcePos?) -> Self {
        Self(firstColumn: firstColumn,
             lastColumn: lastColumn,
             sourcePos: sourcePos)
    }

    /// The list of numbers making up the segment, in sourcemap spec order
    var values: [Int32] {
        var vals = [firstColumn]
        sourcePos.flatMap { vals += $0.values }
        return vals
    }
}
