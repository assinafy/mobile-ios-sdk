import XCTest
@testable import Assinafy

final class BaseResourceTests: XCTestCase {
    private final class ProbeResource: BaseResource {
        func list() async throws -> PaginatedResult<Signer> {
            try await callList("probe list", request: .get("/probe"))
        }

        func cost() async throws -> CostEstimate {
            try await callCostEstimate("probe cost", request: .get("/probe"))
        }

        func void() async throws {
            try await callVoid("probe void", request: .put("/probe"))
        }

        func bridge(completion: @escaping (NSString?, Error?) -> Void) {
            withCompletion({ "ok" as NSString }, completion: completion)
        }
    }

    func testMalformedListFailsClosed() async {
        let mock = MockHTTPClient()
        mock.stub(response: APIResponse(data: Data("not-json".utf8), statusCode: 200))
        let resource = ProbeResource(http: mock)

        do {
            _ = try await resource.list()
            XCTFail("Expected malformed JSON to throw")
        } catch is AssinafySDKError {
        } catch {
            XCTFail("Expected AssinafySDKError, got \(error)")
        }
    }

    func testListEnvelopeWithoutDataFailsClosed() async {
        let mock = MockHTTPClient()
        mock.stubJSON(["status": 200, "message": "missing"])
        let resource = ProbeResource(http: mock)

        await assertThrowsValidationError {
            _ = try await resource.list()
        }
    }

    func testVoidEnvelopePropagatesEmbeddedFailureStatus() async {
        let mock = MockHTTPClient()
        mock.stubJSON(["status": 422, "message": "invalid"])
        let resource = ProbeResource(http: mock)

        do {
            try await resource.void()
            XCTFail("Expected APIError")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 422)
            XCTAssertEqual(error.message, "invalid")
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func testMalformedCostEstimateFailsClosed() async {
        let mock = MockHTTPClient()
        mock.stubEnvelope(["unexpected": "value"])
        let resource = ProbeResource(http: mock)

        do {
            _ = try await resource.cost()
            XCTFail("Expected malformed cost response to throw")
        } catch is AssinafySDKError {
        } catch {
            XCTFail("Expected AssinafySDKError, got \(error)")
        }
    }

    func testCompletionBridgeDeliversOnMainQueue() async {
        let resource = ProbeResource(http: MockHTTPClient())
        let completed = expectation(description: "completion")

        resource.bridge { value, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(value, "ok")
            XCTAssertNil(error)
            completed.fulfill()
        }

        await fulfillment(of: [completed], timeout: 1)
    }
}
