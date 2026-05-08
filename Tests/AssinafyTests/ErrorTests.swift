import XCTest
@testable import Assinafy

final class ErrorTests: XCTestCase {

    func testSDKErrorBridgesToNSError() {
        let error = AssinafySDKError("Something went wrong", context: ["key": "value"])
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, ASFErrorDomain.sdk)
        XCTAssertEqual(nsError.code, -1)
        XCTAssertEqual(nsError.localizedDescription, "Something went wrong")
    }

    func testAPIErrorBridgesToNSError() {
        let error = APIError(statusCode: 400, message: "Bad request", responseData: nil)
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, ASFErrorDomain.api)
        XCTAssertEqual(nsError.code, 400)
        XCTAssertEqual(nsError.localizedDescription, "Bad request")
    }

    func testValidationErrorBridgesToNSError() {
        let error = ValidationError("Invalid input", errors: ["email": "required"])
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, ASFErrorDomain.validation)
        XCTAssertEqual(nsError.code, 422)
        XCTAssertEqual(nsError.localizedDescription, "Invalid input")
    }

    func testNetworkErrorBridgesToNSError() {
        let error = NetworkError("Connection lost")
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, ASFErrorDomain.network)
        XCTAssertEqual(nsError.code, -1009)
        XCTAssertEqual(nsError.localizedDescription, "Connection lost")
    }
}
