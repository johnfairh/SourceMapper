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

extension SourceMap {
    convenience init(url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    static let fixturesURL = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")

    convenience init(fixtureName: String) throws {
        try self.init(url: Self.fixturesURL.appendingPathComponent(fixtureName))
    }
}

func XCTAssertThrows<T: Error>(_ errType: T.Type, _ callback: () throws -> Void) {
    do {
        try callback()
    } catch let error as T {
        print(error)
    } catch {
        XCTFail("Unexpected error: \(error)")
    }
}

func XCTAssertSourceMapError(_ err: SourceMapError, _ callback: () throws -> Void) {
    do {
        try callback()
    } catch let error as SourceMapError {
        XCTAssertEqual(err, error)
        print(error)
    } catch {
        XCTFail("Unexpected error: \(error)")
    }
}
