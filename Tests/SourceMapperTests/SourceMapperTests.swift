import XCTest
@testable import SourceMapper

final class SourceMapperTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(SourceMapper().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
