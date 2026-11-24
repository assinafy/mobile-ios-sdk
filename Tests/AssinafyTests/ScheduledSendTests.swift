import XCTest
@testable import Assinafy

final class ScheduledSendTests: XCTestCase {
    private let scheduled: [String: Any] = [
        "id": "scheduled", "type": "assignment", "document_ids": ["doc"], "status": "pending",
        "send_at": "2099-01-02T00:00:00Z", "created_at": "2099-01-01T00:00:00Z",
        "assignment_id": NSNull(), "envelope_id": NSNull(), "failure_reason": NSNull(), "processed_at": NSNull(),
    ]
    private let sendAt = Date(timeIntervalSince1970: 4_070_995_200)

    func testAssignmentAndEnvelopeSchedulePreservePayloadsAndDecimals() async throws {
        let mock = MockHTTPClient()
        let client = AssinafyClient(http: mock, defaultAccountId: "acc")
        var payload = CreateAssignmentPayload.withSignerIds(["signer"], message: "Later")
        payload.embeddedSignerIds = ["signer"]
        payload.signerCapacities = ["signer": "Witness"]
        payload.maxTotalCredits = Decimal(string: "0.1234567890123456789")
        mock.stubEnvelope(scheduled)
        let result = try await client.assignments.schedule(documentId: "doc", payload: payload, sendAt: sendAt)
        XCTAssertEqual(result.status, "pending")
        XCTAssertNil(result.assignmentId)
        XCTAssertNil(result.processedAt)
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc/scheduled-sends")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        XCTAssertNil(mock.lastRequest?.idempotencyKey)
        let data = try XCTUnwrap(mock.lastRequest?.body)
        let body = try JSONDecoder.assinafy.decode(AssignmentPayloadBody.self, from: data)
        XCTAssertEqual(body.maxTotalCredits, payload.maxTotalCredits)
        XCTAssertEqual(body.message, "Later")
        XCTAssertEqual(body.signers[0].embedded, true)
        XCTAssertEqual(body.signers[0].signAs, "Witness")
        let wire = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(wire["send_at"] as? String, "2099-01-02T00:00:00Z")
        var envelope = CreateEnvelopePayload(name: "Later", signers: [.id("signer")], documents: [.init(id: "doc", signerIds: ["signer"])])
        envelope.maxTotalCredits = payload.maxTotalCredits
        mock.stubEnvelope(scheduled)
        _ = try await client.envelopes.schedule(payload: envelope, sendAt: sendAt)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/scheduled-sends")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        XCTAssertNil(mock.lastRequest?.idempotencyKey)
        XCTAssertEqual(try CreateEnvelopePayload(jsonData: XCTUnwrap(mock.lastRequest?.body)).maxTotalCredits, payload.maxTotalCredits)
    }

    func testListCancelAndSendRoutesAndFailureRemainVisible() async throws {
        let mock = MockHTTPClient()
        let resource = AssignmentResource(http: mock, defaultAccountId: "acc")
        mock.stubEnvelopeList([scheduled], headers: MockHTTPClient.paginationHeaders(currentPage: 2, perPage: 3, total: 4, pageCount: 2))
        let page = try await resource.listScheduledSends(params: ListParams(page: 2, perPage: 3, extra: ["document_id": "doc"]))
        XCTAssertEqual(page.meta?.currentPage, 2)
        XCTAssertEqual(page.data.first?.documentIds, ["doc"])
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/scheduled-sends")
        XCTAssertEqual(mock.lastRequest?.queryItems?.map(\.name), ["page", "per-page", "document_id"])
        var response = scheduled
        response["status"] = "cancelled"
        mock.stubEnvelope(response)
        let cancelled = try await resource.cancelScheduledSend(scheduledSendId: "scheduled")
        XCTAssertEqual(cancelled.status, "cancelled")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/scheduled-sends/scheduled/cancel")
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        mock.stub(error: APIError(statusCode: 409, message: "Ceiling exceeded", responseData: ["code": "CreditCeilingExceeded"]))
        do {
            _ = try await resource.sendScheduledSend(scheduledSendId: "scheduled")
            XCTFail("Expected the server refusal")
        } catch let error as APIError { XCTAssertEqual(error.statusCode, 409) }
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/scheduled-sends/scheduled/send")
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.allRequests.count, 3, "An unsuccessful send must not be retried")
        response["status"] = "failed"
        response["failure_reason"] = "The author left the workspace"
        let failed = try JSONDecoder.assinafy.decode(ScheduledSend.self, from: JSONSerialization.data(withJSONObject: response))
        XCTAssertEqual(failed.failureReason, "The author left the workspace")
    }

    func testSchedulingValidationAndCompletionAdapters() async throws {
        let mock = MockHTTPClient()
        let client = AssinafyClient(http: mock, defaultAccountId: "acc")
        let payload = CreateAssignmentPayload.withSignerIds(["s"])
        do {
            _ = try await client.assignments.schedule(documentId: "doc", payload: payload, sendAt: Date(timeIntervalSince1970: .infinity))
            XCTFail("Expected date validation")
        } catch is ValidationError {}
        XCTAssertTrue(mock.allRequests.isEmpty)
        mock.stubEnvelope(scheduled)
        let done = expectation(description: "assignment schedule main queue")
        client.assignments.schedule(documentId: "doc", payloadJSON: Data(#"{"method":"virtual","signers":[{"id":"s","sign_as":"Witness"}]}"#.utf8), sendAt: sendAt) { value, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(value?.id, "scheduled")
            XCTAssertNil(error)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 5)
        mock.stubEnvelope(scheduled)
        let envelopeDone = expectation(description: "envelope schedule main queue")
        client.envelopes.schedule(payloadJSON: Data(#"{"name":"Later","signers":[{"id":"s"}],"documents":[{"id":"doc","signer_ids":["s"]}]}"#.utf8), sendAt: sendAt, accountId: nil) { value, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNotNil(value)
            XCTAssertNil(error)
            envelopeDone.fulfill()
        }
        await fulfillment(of: [envelopeDone], timeout: 5)
    }

    func testCapacityRoundTripAndEstimation() throws {
        let json = Data(#"{"method":"virtual","signers":[{"id":"s","sign_as":"Witness"},{"id":"t","sign_as":null}]}"#.utf8)
        var payload = try CreateAssignmentPayload(jsonData: json)
        XCTAssertEqual(payload.signerCapacities, ["s": "Witness"])
        let wire = try JSONEncoder.assinafy.encode(buildAssignmentBody(payload))
        XCTAssertEqual(try CreateAssignmentPayload(jsonData: wire).signerCapacities, payload.signerCapacities)
        XCTAssertEqual(try buildAssignmentEstimateBody(payload).signers?.first?.signAs, "Witness")
        payload.signerCapacities["unknown"] = "Sign"
        XCTAssertThrowsError(try buildAssignmentBody(payload))
        XCTAssertThrowsError(try buildAssignmentEstimateBody(payload))
        XCTAssertThrowsError(try CreateAssignmentPayload(jsonData: Data(#"{"method":"virtual","signers":[{"id":"s","sign_as":"Witness"},{"id":"s","sign_as":"Party"}]}"#.utf8)))
    }
}
