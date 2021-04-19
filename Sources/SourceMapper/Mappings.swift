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
        let newSegments = try decodeMappings()
        segments = newSegments
        return newSegments
    }

    /// Update the mapping segments.  No validation done against `sources` or `names`.
    public func setSegments(_ segments: [[Segment]]) {
        self.segments = segments
        mappingsValid = false
    }

    /// Unpack the `mappings` string
    private func decodeMappings() throws -> [[Segment]] {
        var coder = MappingCoder()

        return try mappings.split(separator: ";", omittingEmptySubsequences: false).map { line in
            coder.newLine()
            var lineSegs = try line.split(separator: ",").map {
                try Segment(values: coder.decodeValues(deltas: try VLQ.decode($0)))
            }
            if lineSegs.count > 1 {
                for i in 0..<lineSegs.count - 1 {
                    lineSegs[i].lastColumn = lineSegs[i+1].firstColumn - 1
                }
            }
            return lineSegs
        }
    }

    /// Update the `mappings` string from the segments data
    func encodeMappings(continueOnError: Bool) throws {
        var coder = MappingCoder()

        precondition(!mappingsValid)
        let lineStrings = try getSegments().map { line -> String in
            coder.newLine()
            return try line.map { segment in
                if !continueOnError {
                    try segment.sourcePos?.check(sourceCount: sources.count, namesCount: names.count)
                }
                return VLQ.encode(coder.encodeDeltas(values: segment.values))
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

// MARK: Mapping segment delta tracking

private struct MappingCoder {
    static let LENGTH = 5
    private var counters: [Int32]

    init() {
        counters = .init(repeating: 0, count: Self.LENGTH)
    }

    /// new line - reset column counter
    mutating func newLine() {
        counters[0] = 0
    }

    /// encode: given a list of segment values, return the delta for storing in mappings
    mutating func encodeDeltas(values: [Int32]) -> [Int32] {
        values.enumerated().map { (n, value) in
            let newValue = value - counters[n]
            counters[n] = value
            return newValue
        }
    }

    /// decode: given a list of deltas, return the absolute values
    mutating func decodeValues(deltas: [Int32]) -> [Int32] {
        deltas.prefix(Self.LENGTH).enumerated().map { (n, delta) in
            let newValue = counters[n] + delta
            counters[n] = newValue
            return newValue
        }
    }
}

extension SourceMap.SourcePos {
    /// Init from a list of values in sourcemap spec order.  Index 0 is the generated file column index.
    init(values: [Int32]) {
        self.init(source: values[1],
                  line: values[2],
                  column: values[3],
                  name: values.count > 4 ? values[4] : nil)
    }

    /// The list of numbers making up the pos part of the segment, in sourcemap spec order
    var values: [Int32] {
        var arr = [source, line, column]
        if let name = name {
            arr.append(name)
        }
        return arr
    }
}

extension SourceMap.Segment {
    /// Init from a list of values in sourcemap spec order
    init(values: [Int32]) throws {
        switch values.count {
        case 1:
            self.init(firstColumn: values[0])
        case 4, 5:
            self.init(firstColumn: values[0], sourcePos: .init(values: values))
        default:
            throw SourceMapError.invalidVLQStringLength(values)
        }
    }

    /// The list of numbers making up the segment, in sourcemap spec order
    var values: [Int32] {
        var vals = [firstColumn]
        sourcePos.flatMap { vals += $0.values }
        return vals
    }
}

// MARK: Validation and fixups

extension SourceMap.SourcePos {
    /// Version of this pos with any `name` erased
    var withoutName: Self {
        Self(source: source, line: line, column: column)
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
}
