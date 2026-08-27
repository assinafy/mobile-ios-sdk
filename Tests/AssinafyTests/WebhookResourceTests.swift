import XCTest
@testable import Assinafy

final class WebhookResourceTests: XCTestCase {
    var mock: MockHTTPClient!
    var resource: WebhookResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        resource = WebhookResource(http: mock, defaultAccountId: "test-account")
    }

    private func subscriptionDict() -> [String: Any] {
        [
            "events": ["document_ready"],
            "is_active": true,
            "url": "https://example.com/hook",
            "email": "test@example.com",
            "updated_at": "2024-01-01T00:00:00Z",
        ]
    }

    private func dispatchDict(id: String = "d1") -> [String: Any] {
        [
            "resource": "activity_dispatching_history",
            "id": id,
            "event": "document_ready",
            "activity_id": 1,
            "payload": ["document": ["id": "doc1"], "attempt": 1],
            "delivered": true,
            "http_status": 200,
            "created_at": "2026-07-20T19:03:13Z",
            "updated_at": "2026-07-20T19:03:13Z",
        ]
    }

    func testRegisterUsesCorrectEndpoint() async throws {
        mock.stubEnvelope(subscriptionDict())
        _ = try await resource.register(WebhookRegisterPayload(url: "https://example.com/hook", email: "test@example.com"))
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/webhooks/subscriptions")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testGetUsesCorrectEndpoint() async throws {
        mock.stubEnvelope(subscriptionDict())
        _ = try await resource.get()
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/webhooks/subscriptions")
        XCTAssertEqual(mock.lastRequest?.method, .get)
    }

    @available(*, deprecated, message: "Exercises the deprecated source-compatible alias.")
    func testDeleteForwardsToInactivate() async throws {
        // The API has no destructive DELETE for subscriptions; the deprecated
        // delete() forwards to the documented inactivate endpoint.
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 204))
        try await resource.delete()
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/webhooks/inactivate")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testDispatchDecodesIsoTimestamps() async throws {
        mock.stubEnvelope(dispatchDict())
        let dispatch = try await resource.retryDispatch(dispatchId: "d1")
        XCTAssertEqual(dispatch.createdAt, "2026-07-20T19:03:13Z")
        XCTAssertEqual(dispatch.httpStatusCode?.intValue, 200)
        XCTAssertEqual(dispatch.resource, "activity_dispatching_history")
        XCTAssertEqual(dispatch.payload?["attempt"] as? Int, 1)
        XCTAssertEqual((dispatch.payload?["document"] as? [String: Any])?["id"] as? String, "doc1")
    }

    func testInactivateHitsDocumentedEndpoint() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.inactivate()
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/webhooks/inactivate")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testInactivateAndReturnDecodesUpdatedSubscription() async throws {
        var subscription = subscriptionDict()
        subscription["is_active"] = false
        mock.stubEnvelope(subscription)
        let result = try await resource.inactivateAndReturn()
        XCTAssertFalse(result.isActive)
        XCTAssertEqual(result.url, "https://example.com/hook")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/webhooks/inactivate")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testDispatchPreservesNullHTTPStatus() async throws {
        var dispatch = dispatchDict()
        dispatch["http_status"] = NSNull()
        mock.stubEnvelope(dispatch)
        let result = try await resource.retryDispatch(dispatchId: "d1")
        XCTAssertNil(result.httpStatusCode)
    }

    func testListEventTypesCallsGlobalEndpoint() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.listEventTypes()
        XCTAssertEqual(mock.lastRequest?.path, "/webhooks/event-types")
    }

    func testListDispatchesSendsQueryFilters() async throws {
        mock.stubEnvelopeList([])
        let params = WebhookDispatchListParams(page: 2, perPage: 20, event: "document_signed", delivered: false, hasDeliveredFilter: true)
        _ = try await resource.listDispatches(params: params)
        let queryItems = mock.lastRequest?.queryItems ?? []
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "page", value: "2")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "per-page", value: "20")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "event", value: "document_signed")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "delivered", value: "false")))
    }

    func testRetryDispatchUsesCorrectPath() async throws {
        mock.stubEnvelope(dispatchDict())
        _ = try await resource.retryDispatch(dispatchId: "d1")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/webhooks/d1/retry")
        XCTAssertEqual(mock.lastRequest?.method, .post)
    }

    func testRetryDispatchRequiresDispatchID() async {
        await assertThrowsValidationError {
            _ = try await self.resource.retryDispatch(dispatchId: "")
        }
    }

    func testRequiresAccountID() async {
        let noAccount = WebhookResource(http: mock, defaultAccountId: nil)
        await assertThrowsValidationError {
            _ = try await noAccount.register(WebhookRegisterPayload(url: "https://example.com/hook", email: "test@example.com"))
        }
    }

    func testRegisterDefaultEventsIncludeExpectedEvents() {
        let payload = WebhookRegisterPayload(url: "https://example.com/hook", email: "test@example.com")
        XCTAssertTrue(payload.events.contains("document_ready"))
        XCTAssertTrue(payload.events.contains("signer_signed_document"))
        XCTAssertTrue(payload.events.contains("signer_rejected_document"))
    }

    func testRegisterRejectsInvalidURLAndEmailBeforeRequest() async {
        await assertThrowsValidationError {
            _ = try await self.resource.register(
                WebhookRegisterPayload(url: "relative/path", email: "invalid")
            )
        }
        await assertThrowsValidationError {
            _ = try await self.resource.register(
                WebhookRegisterPayload(url: "https://example.com/hook", email: "invalid")
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }
}
