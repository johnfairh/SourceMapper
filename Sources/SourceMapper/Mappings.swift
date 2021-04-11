//
//  Mappings.swift
//  SourceMapper
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

import Foundation

extension SourceMap {
    /// One list of `MappingSegment`s for every line in the generated code file.
    ///
    /// Decodes the mappings if necessary.
    /// - throws: If the mappings are undecodable in some way indicating a corrupt source map.
    ///   No error is thrown for invalid indicies - an `invalidSegment` is substituted and the offence
    ///   reported  in  `invalidSegmentReports`.
    public func getMappingSegments() throws -> [[MappingSegment]] {
        if let segments = mappingSegments {
            return segments
        }
        let newSegments = try unpackMappings()
        mappingSegments = newSegments
        return newSegments
    }

    /// Update the mapping segments.  No validation done against `sources` or `names`.
    public func setMappingSegments(_ segments: [[MappingSegment]]) {
        mappingSegments = segments
        mappingsValid = false
    }

    /// Unpack the `mappings` string
    func unpackMappings() throws -> [[MappingSegment]] {
        var sourceIndex = Int32(0)
        var sourceLine = Int32(0)
        var sourceColumn = Int32(0)
        var nameIndex = Int32(0)

        return try mappings.split(separator: ";").map { line in
            var generatedColumn = Int32(0)
            return try line.split(separator: ",").map { seg in
                let numbers = try VLQ.decode(seg)
                if numbers.count == 1 {
                    // what does this actually mean? just signal end of prev span?
                    preconditionFailure()
                }
                if numbers.count < 4 || numbers.count > 5 {
                    // throw badness
                    preconditionFailure()
                }
                defer {
                    generatedColumn += numbers[0]
                    sourceIndex += numbers[1]
                    sourceLine += numbers[2]
                    sourceColumn += numbers[3]
                    if numbers.count == 5 {
                        nameIndex += numbers[4]
                    }
                }
                return .init(generatedColumnIndex: numbers[0] + generatedColumn,
                             sourceIndex: numbers[1] + sourceIndex,
                             sourceLineIndex: numbers[2] + sourceLine,
                             sourceColumnIndex: numbers[3] + sourceColumn,
                             nameIndex: numbers.count == 5 ? (numbers[4] + nameIndex) : nil)
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
    public func map(rowIndex: Int, columnIndex: Int) throws -> MappingSegment? {
        let segs = try getMappingSegments()
        guard rowIndex < segs.count else {
            return nil
        }
        let rowSegs = segs[rowIndex]
        switch rowSegs.count {
        case 0: return nil
        case 1: return rowSegs[0]
        default:
            if columnIndex < rowSegs[0].generatedColumnIndex {
                return nil
            }
            // xxx should binary search but in practice not a lot of entries....
            for n in 0 ..< rowSegs.count {
                if columnIndex < rowSegs[n].generatedColumnIndex {
                    return rowSegs[n - 1]
                }
            }
            return rowSegs.last
        }
    }
}
