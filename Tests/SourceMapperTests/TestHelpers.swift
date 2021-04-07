//
//  TestHelpers.swift
//  SourceMapperTests
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

import Foundation
import SourceMapper
import XCTest

extension SourceMap: Equatable {
    public static func == (lhs: SourceMap, rhs: SourceMap) -> Bool {
        var lhs = lhs, rhs = rhs
        let lhsJSON, rhsJSON : String
        do {
            lhsJSON = try lhs.encodeString()
        } catch {
            XCTFail("Can't check equality, lhs broken: \(error)")
            return false
        }
        do {
            rhsJSON = try rhs.encodeString()
        } catch {
            XCTFail("Can't check equality, lhs broken: \(error)")
            return false
        }
        return lhsJSON == rhsJSON
    }
}
