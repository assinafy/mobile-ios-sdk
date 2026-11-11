import XCTest
@testable import Assinafy

final class EnvelopeResourceTests: XCTestCase {
    private let envelope: [String: Any] = [
        "id": "env", "name": "Agreement", "message": NSNull(), "documents": [],
        "counts": NSNull(), "signing_urls": [["signer_id": "s", "url": NSNull(), "embedded": true]],
        "created_at": "2026-11-11T12:00:00Z"
    ]

    func testEnvelopeLifecycleRequestsAndResponses() async throws {
        let mock = MockHTTPClient()
        let resource = EnvelopeResource(http: mock, defaultAccountId: "acc")
        var payload = CreateEnvelopePayload(name: "Agreement", signers: [.id("s")],
                                            documents: [.init(id: "d", signerIds: ["s"])])
        payload.maxTotalCredits = Decimal(string: "0.45")
        payload.embeddedSignerIds = ["s"]
        func check(_ method: HTTPMethod, _ suffix: String) {
            XCTAssertEqual(mock.lastRequest?.method, method)
            XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/envelopes" + suffix)
            XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        }
        mock.stubEnvelope(envelope)
        let created = try await resource.create(payload: payload, idempotencyKey: "unique-key")
        check(.post, "")
        XCTAssertNil(created.counts)
        XCTAssertNil(created.signingUrls.first?.signingURL)
        XCTAssertTrue(created.signingUrls.first?.embedded == true)
        XCTAssertEqual(mock.lastRequest?.idempotencyKey, "unique-key")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(mock.lastRequest?.body)) as? [String: Any])
        XCTAssertEqual(body["max_total_credits"] as? Double, 0.45)
        XCTAssertEqual((body["signers"] as? [[String: Any]])?.first?["embedded"] as? Bool, true)
        mock.stubEnvelope(["total_credits": 0.45, "has_sufficient_resources": true])
        let estimate = try await resource.estimateCost(payload: payload)
        check(.post, "/estimate-cost")
        XCTAssertEqual(estimate.totalCredits, 0.45)
        mock.stubEnvelopeList([envelope], headers: MockHTTPClient.paginationHeaders(currentPage: 2, perPage: 3, total: 4, pageCount: 2))
        let list = try await resource.list(params: ListParams(page: 2, perPage: 3, search: "Agreement"), status: "open")
        check(.get, "")
        XCTAssertEqual(list.meta?.currentPage, 2)
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.value, "2")
        XCTAssertEqual(mock.lastRequest?.queryItems?.last?.value, "open")
        mock.stubEnvelope(envelope)
        _ = try await resource.get(envelopeId: "env")
        check(.get, "/env")
        let update = UpdateEnvelopePayload()
        update.clearMessage = true
        update.documentIds = ["d"]
        mock.stubEnvelope(envelope)
        _ = try await resource.update(envelopeId: "env", payload: update)
        check(.patch, "/env")
        let updateBody = try JSONSerialization.jsonObject(with: XCTUnwrap(mock.lastRequest?.body)) as? [String: Any]
        XCTAssertTrue(updateBody?["message"] is NSNull)
        mock.stubEnvelope(envelope)
        _ = try await resource.addDocument(envelopeId: "env", payload: .init(id: "new", signerIds: ["s"]))
        check(.post, "/env/documents")
        mock.stubEnvelope(envelope)
        _ = try await resource.removeDocument(envelopeId: "env", documentId: "new")
        check(.delete, "/env/documents/new")
        mock.stubEnvelope(["is_sent": true, "envelope_id": "env", "signer_id": "s"])
        let reminder = try await resource.resendNotification(envelopeId: "env", signerId: "s")
        check(.put, "/env/signers/s/resend")
        XCTAssertEqual(reminder.envelopeId, "env")
        mock.stubEnvelopeList([["id": 1, "event": "created", "message": "Created", "origin": "api",
                                "created_at": "2026-11-11", "document_id": "d", "document_name": "Agreement"]])
        let activity = try await resource.activities(envelopeId: "env", params: ListParams(page: 2))
        check(.get, "/env/activities")
        XCTAssertEqual(activity.data.first?.documentId, "d")
        mock.stub(response: APIResponse(data: Data("zip".utf8), statusCode: 200))
        let zip = try await resource.download(envelopeId: "env", artifact: .bundle)
        check(.get, "/env/download/bundle")
        XCTAssertEqual(zip, Data("zip".utf8))
        mock.stubEnvelopeList([["id": "d", "status": "rejected_by_user", "cancelled": true]])
        let cancelled = try await resource.cancel(envelopeId: "env")
        check(.put, "/env/cancel")
        XCTAssertTrue(cancelled[0].cancelled)
        mock.stubEnvelopeList([])
        try await resource.delete(envelopeId: "env")
        check(.delete, "/env")
    }

    func testEnvelopeValidationAndJSONRoundTrip() throws {
        let json = Data(#"{"name":"Agreement","signers":[{"id":"s","embedded":true}],"documents":[{"id":"d","signer_ids":["s"]}],"max_total_credits":0.45}"#.utf8)
        let payload = try CreateEnvelopePayload(jsonData: json)
        let encoded = try JSONEncoder.assinafy.encode(payload)
        let rebuilt = try CreateEnvelopePayload(jsonData: encoded)
        XCTAssertEqual(rebuilt.embeddedSignerIds, ["s"])
        XCTAssertEqual(rebuilt.maxTotalCredits, Decimal(string: "0.45"))
        let precise = try CreateEnvelopePayload(jsonData: Data(#"{"name":"Pack","signers":[{"id":"s"}],"documents":[{"id":"d","signer_ids":["s"],"max_total_credits":0.1234567890123456789}]}"#.utf8))
        XCTAssertEqual(precise.documents[0].maxTotalCredits, Decimal(string: "0.1234567890123456789"))
        XCTAssertEqual(try JSONEncoder.assinafy.encode(rebuilt), encoded)
        var invalid = payload
        invalid.signers = [.descriptor(id: "s", step: 1)]
        XCTAssertThrowsError(try JSONEncoder.assinafy.encode(invalid))
        invalid = payload
        invalid.documents = [.init(id: "d", signerIds: ["other"])]
        XCTAssertThrowsError(try JSONEncoder.assinafy.encode(invalid))
        invalid = payload
        invalid.signers = [.signer(id: "s", verification: .digitalCertificate)]
        invalid.documents[0].method = .collect
        XCTAssertThrowsError(try JSONEncoder.assinafy.encode(invalid))
        invalid = payload
        invalid.maxTotalCredits = .nan
        XCTAssertThrowsError(try JSONEncoder.assinafy.encode(invalid))
        invalid = payload
        invalid.documents[0].signerIds = ["s", "s"]
        XCTAssertThrowsError(try JSONEncoder.assinafy.encode(invalid))
        invalid = payload
        invalid.name = "<bad>"
        XCTAssertThrowsError(try JSONEncoder.assinafy.encode(invalid))
        let update = UpdateEnvelopePayload()
        update.clearMessage = true
        update.message = "conflict"
        XCTAssertThrowsError(try JSONEncoder.assinafy.encode(update))
    }

    func testObjectiveCCreationBridgeRunsOnMainQueue() async throws {
        let mock = MockHTTPClient()
        mock.stubEnvelope(envelope)
        let resource = EnvelopeResource(http: mock, defaultAccountId: "acc")
        let done = expectation(description: "main completion")
        resource.create(payloadJSON: Data(#"{"name":"Agreement","signers":[{"id":"s"}],"documents":[{"id":"d","signer_ids":["s"]}]}"#.utf8), idempotencyKey: "key", accountId: nil) { value, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(value?.id, "env")
            XCTAssertNil(error)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 5)
        XCTAssertEqual(mock.lastRequest?.idempotencyKey, "key")
    }
}
