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

    func testWorkspaceDeletionRestrictionsAreTyped() {
        let error = APIError(
            statusCode: 400,
            message: "Deletion blocked",
            responseData: [
                "restrictions": [[
                    "code": "ActivePaidSubscription",
                    "message": "Workspace has an active subscription.",
                    "account_ids": ["account-1"],
                ]],
            ]
        )

        XCTAssertEqual(error.workspaceDeletionRestrictions.count, 1)
        XCTAssertEqual(error.workspaceDeletionRestrictions[0].code, "ActivePaidSubscription")
        XCTAssertEqual(error.workspaceDeletionRestrictions[0].accountIds, ["account-1"])
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

    func testNetworkErrorPreservesUnderlyingURLErrorCode() {
        let error = NetworkError("Timed out", underlyingError: URLError(.timedOut))
        XCTAssertEqual((error as NSError).code, URLError.timedOut.rawValue)
    }
}
