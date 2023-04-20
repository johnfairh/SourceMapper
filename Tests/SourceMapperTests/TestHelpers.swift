//
//  TestHelpers.swift
//  SourceMapperTests
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

import Foundation
import SourceMapper
import XCTest

extension SourceMap {
    init(url: URL) throws {
        try self.init(try Data(contentsOf: url))
    }

    static let fixturesURL = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")

    init(fixtureName: String) throws {
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
        XCTFail("Did not throw any errors")
    } catch let error as SourceMapError {
        XCTAssertEqual(err, error)
        print(error)
    } catch {
        XCTFail("Unexpected error: \(error)")
    }
}
