//
//  Mappings.swift
//  SourceMapper
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

import Foundation

extension SourceMap {
    /// One list of ``Segment``s for every line in the generated code file.
    ///
    /// Use ``set(segments:validate:)`` to write this field.
    ///
    /// - throws: If the mappings are seriously undecodable in some way indicating a
    ///   corrupt source map.  Invalid indices do not cause errors.
    public var segments: [[Segment]] {
        get throws {
            guard !mappings.isEmpty else { return [] }

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
    }

    /// Update the mappings.
    ///
    /// - parameter segments: The segments to replace the current source map's mappings
    /// - parameter validate: Whether to check ``segments`` against ``sources`` or ``names``.
    ///   If this is `false` then any inconsistencies are passed through unchanged to `mappings`.
    ///
    ///   The default is `false` which is probably right when working with existing source maps,
    ///   but if you're creating from scratch it may be more useful to set `true` to catch bugs
    ///   in your generation code.
    ///
    /// - throws: Only if ``validate`` is set and there is a mismatch.
    public mutating func set(segments: [[Segment]], validate: Bool = false) throws {
        var coder = MappingCoder()

        let lineStrings = try segments.map { line -> String in
            coder.newLine()
            return try line.map { segment in
                if validate {
                    try segment.sourcePos?.check(sourceCount: sources.count, namesCount: names.count)
                }
                return VLQ.encode(coder.encodeDeltas(values: segment.values))
            }.joined(separator: ",")
        }

        mappings = lineStrings.joined(separator: ";")
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
            throw SourceMapError.invalidSource(Int(source), count: sourceCount)
        }
        if let name = name, name >= namesCount {
            throw SourceMapError.invalidName(Int(name), count: namesCount)
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
