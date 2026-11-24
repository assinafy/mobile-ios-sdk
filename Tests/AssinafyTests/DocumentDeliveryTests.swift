import XCTest
@testable import Assinafy

final class DocumentDeliveryTests: XCTestCase {
    func testWatchersCapacitiesAndDeliveryHistory() async throws {
        let mock = MockHTTPClient()
        let resource = DocumentResource(http: mock)
        mock.stubEnvelopeList([["id": "s", "full_name": "Example", "email": "signer@example.invalid"]])
        let watchers = try await resource.setWatchers(documentId: "d", watcherIds: ["s"])
        XCTAssertEqual(watchers.first?.id, "s")
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/d/watchers")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        let body = try JSONDecoder().decode([String: [String]].self, from: XCTUnwrap(mock.lastRequest?.body))
        XCTAssertEqual(body, ["watcher_ids": ["s"]])
        mock.stubEnvelopeList([])
        _ = try await resource.setWatchers(documentId: "d", watcherIds: [])
        XCTAssertEqual(try JSONDecoder().decode([String: [String]].self, from: XCTUnwrap(mock.lastRequest?.body)), ["watcher_ids": []])
        mock.stubEnvelopeList([])
        _ = try await resource.watchers(documentId: "d")
        XCTAssertEqual(mock.lastRequest?.method, .get)
        mock.stubEnvelopeList([["signer_id": "s", "sign_as": "Witness"]])
        let capacities = try await resource.signerCapacities(documentId: "d")
        XCTAssertEqual(capacities.first?.signAs, "Witness")
        XCTAssertEqual(mock.lastRequest?.path, "/documents/d/signer-capacities")
        mock.stubEnvelopeList([["signer_id": "s", "notification_history": [[
            "event": "signature_requested", "status": "sent", "sent_at": "2099-01-01T12:00:00Z",
            "delivered_at": "2099-01-01T12:00:05Z", "opened_at": NSNull(),
        ]]]])
        let history = try await resource.notificationHistory(documentId: "d")
        XCTAssertEqual(mock.lastRequest?.path, "/documents/d/notification-history")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        XCTAssertEqual(history.first?.notificationHistory.first?.deliveredAt, "2099-01-01T12:00:05Z")
        XCTAssertNil(history.first?.notificationHistory.first?.openedAt)
        let old = try JSONDecoder.assinafy.decode(SignerNotificationHistory.self, from: Data(#"{"event":"sent","status":"sent"}"#.utf8))
        XCTAssertNil(old.deliveredAt)
        XCTAssertNil(old.openedAt)
    }

    func testInvalidWatchersFailBeforeIOAndCompletionUsesMainQueue() async throws {
        let mock = MockHTTPClient()
        let resource = DocumentResource(http: mock)
        for ids in [["../other"], [""], Array(repeating: "s", count: 11)] {
            do {
                _ = try await resource.setWatchers(documentId: "d", watcherIds: ids)
                XCTFail("Expected watcher validation")
            } catch is ValidationError {}
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
        mock.stubEnvelopeList([])
        let done = expectation(description: "watchers on main")
        resource.setWatchers(documentId: "d", watcherIds: []) { result, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(result?.count, 0)
            XCTAssertNil(error)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 5)
    }

    func testEnvelopeReminderAndWebhookTestRoutes() async throws {
        let mock = MockHTTPClient()
        let client = AssinafyClient(http: mock, defaultAccountId: "acc")
        mock.stubEnvelope(["total": 0.45, "has_sufficient_credits": true])
        let cost = try await client.envelopes.estimateResendCost(envelopeId: "env", signerId: "s")
        XCTAssertEqual(cost.totalCredits, 0.45)
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/envelopes/env/signers/s/estimate-resend-cost")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        mock.stubEnvelope(["id": "delivery", "event": "webhook_test", "kind": "manual", "delivered": false, "duration_ms": 123,
                           "payload": NSNull(), "origin": NSNull(), "attempt": 1, "will_retry": false])
        let delivery = try await client.webhooks.testEndpoint(endpointId: "endpoint")
        XCTAssertEqual(delivery.kind, "manual")
        XCTAssertEqual(delivery.durationMilliseconds?.intValue, 123)
        XCTAssertFalse(delivery.willRetry)
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/webhooks/endpoints/endpoint/test")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
    }

    func testJPEGSignatureUsesItsMediaTypeAndWithholdsCredential() async throws {
        let mock = MockHTTPClient()
        mock.stubJSON(["status": 200, "data": NSNull()])
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])
        try await SignerResource(http: mock).uploadSignature(signerAccessCode: "code", type: .initial, imageData: jpeg, reusePreference: false)
        XCTAssertEqual(mock.lastRequest?.contentType, "image/jpeg")
        XCTAssertEqual(mock.lastRequest?.body, jpeg)
        XCTAssertEqual(mock.lastRequest?.credential, .withheld)
        XCTAssertEqual(mock.lastRequest?.queryItems?.last?.value, "false")
    }
}
