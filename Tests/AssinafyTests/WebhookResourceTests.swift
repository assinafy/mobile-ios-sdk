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
            "is_held": true,
            "held_since": 1_790_000_000,
            "url": "https://example.invalid/hook",
            "email": "test@example.invalid",
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
            "webhook_id": "delivery-1",
            "attempt": 2,
            "kind": "manual",
            "will_retry": false,
            "http_status": 200,
            "created_at": "2026-07-20T19:03:13Z",
            "updated_at": "2026-07-20T19:03:13Z",
        ]
    }

    func testRegisterUsesCorrectEndpoint() async throws {
        mock.stubEnvelope(subscriptionDict())
        _ = try await resource.register(WebhookRegisterPayload(url: "https://example.invalid/hook", email: "test@example.invalid"))
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/webhooks/subscriptions")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testGetUsesCorrectEndpoint() async throws {
        mock.stubEnvelope(subscriptionDict())
        let subscription = try await resource.get()
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/webhooks/subscriptions")
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertTrue(subscription.isHeld)
        XCTAssertEqual(subscription.heldSince?.intValue, 1_790_000_000)
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
        XCTAssertEqual(dispatch.webhookId, "delivery-1")
        XCTAssertEqual(dispatch.attempt?.intValue, 2)
        XCTAssertEqual(dispatch.kind, "manual")
        XCTAssertFalse(dispatch.willRetry)
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
        XCTAssertEqual(result.url, "https://example.invalid/hook")
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

    func testDispatchRetryMetadataPreservesNullAndFutureKinds() throws {
        var response = dispatchDict()
        response["webhook_id"] = NSNull()
        response["attempt"] = NSNull()
        response["kind"] = "future-kind"
        response["will_retry"] = true
        let retrying = try JSONDecoder.assinafy.decode(
            WebhookDispatch.self, from: JSONSerialization.data(withJSONObject: response))
        XCTAssertNil(retrying.webhookId)
        XCTAssertNil(retrying.attempt)
        XCTAssertEqual(retrying.kind, "future-kind")
        XCTAssertTrue(retrying.willRetry)

        for key in ["webhook_id", "attempt", "kind", "will_retry"] { response.removeValue(forKey: key) }
        let legacy = try JSONDecoder.assinafy.decode(
            WebhookDispatch.self, from: JSONSerialization.data(withJSONObject: response))
        XCTAssertNil(legacy.webhookId)
        XCTAssertNil(legacy.attempt)
        XCTAssertNil(legacy.kind)
        XCTAssertFalse(legacy.willRetry)
    }

    func testContractWebhookEventNames() {
        XCTAssertEqual([
            WebhookEventType.documentContractUpdated, WebhookEventType.documentContractRenewalNotice,
            WebhookEventType.documentContractExpiring, WebhookEventType.documentContractExpired,
            WebhookEventType.documentContractRenewed, WebhookEventType.documentContractTerminated,
            WebhookEventType.documentContractAmended, WebhookEventType.documentContractAmendmentUpdated,
        ], [
            "document_contract_updated", "document_contract_renewal_notice", "document_contract_expiring",
            "document_contract_expired", "document_contract_renewed", "document_contract_terminated",
            "document_contract_amended", "document_contract_amendment_updated",
        ])
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
            _ = try await noAccount.register(WebhookRegisterPayload(url: "https://example.invalid/hook", email: "test@example.invalid"))
        }
    }

    func testRegisterDefaultEventsIncludeExpectedEvents() {
        let payload = WebhookRegisterPayload(url: "https://example.invalid/hook", email: "test@example.invalid")
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
                WebhookRegisterPayload(url: "https://example.invalid/hook", email: "invalid")
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }
}
