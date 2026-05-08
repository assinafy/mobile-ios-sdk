import XCTest
@testable import Assinafy

func assertThrowsValidationError(
    _ block: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await block()
        XCTFail("Expected ValidationError", file: file, line: line)
    } catch is ValidationError {
    } catch {
        XCTFail("Expected ValidationError, got \(type(of: error)): \(error)", file: file, line: line)
    }
}
