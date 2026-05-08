import XCTest
@testable import Assinafy

final class AssignmentPayloadTests: XCTestCase {

    func testWithSignerIdsConvenienceMethod() {
        let payload = CreateAssignmentPayload.withSignerIds(["s1", "s2"], method: .virtual)
        XCTAssertEqual(payload.signers.count, 2)
        XCTAssertEqual(payload.method, .virtual)
    }

    func testThrowsOnEmptySignersArray() {
        do {
            _ = try buildAssignmentBody(CreateAssignmentPayload(signers: []))
            XCTFail("Expected ValidationError")
        } catch is ValidationError {
        } catch {
            XCTFail("Expected ValidationError, got \(type(of: error)): \(error)")
        }
    }

    func testThrowsOnEmptySignerID() {
        let payload = CreateAssignmentPayload(signers: [.id("")])
        do {
            _ = try buildAssignmentBody(payload)
            XCTFail("Expected ValidationError")
        } catch is ValidationError {
        } catch {
            XCTFail("Expected ValidationError, got \(type(of: error)): \(error)")
        }
    }

    func testNormalisesStringSignerIDsIntoObjects() {
        let payload = CreateAssignmentPayload.withSignerIds(["s1", "s2"])
        let body = try! buildAssignmentBody(payload)
        XCTAssertEqual(body.signers[0].id, "s1")
        XCTAssertEqual(body.signers[1].id, "s2")
    }

    func testCollectAssignmentsRequireEntries() {
        let payload = CreateAssignmentPayload(method: .collect, signers: [.id("s1")], entries: nil)
        do {
            _ = try buildAssignmentBody(payload)
            XCTFail("Expected ValidationError")
        } catch is ValidationError {
        } catch {
            XCTFail("Expected ValidationError, got \(type(of: error)): \(error)")
        }
    }

    func testCollectAssignmentsEncodeEntries() {
        let field = AssignmentField(signerId: "s1", fieldId: "f1")
        let entry = AssignmentEntry(pageId: "p1", fields: [field])
        let payload = CreateAssignmentPayload(method: .collect, signers: [.id("s1")], entries: [entry])
        let body = try! buildAssignmentBody(payload)
        XCTAssertEqual(body.entries?.count, 1)
        XCTAssertEqual(body.entries?[0].pageId, "p1")
        XCTAssertEqual(body.entries?[0].fields[0].signerId, "s1")
    }

    func testIncludesOptionalFieldsWhenProvided() {
        let payload = CreateAssignmentPayload(
            signers: [.id("s1")],
            message: "Please sign",
            expiresAt: "2025-01-01"
        )
        let body = try! buildAssignmentBody(payload)
        XCTAssertEqual(body.message, "Please sign")
        XCTAssertEqual(body.expiresAt, "2025-01-01")
    }

    func testOmitsUndefinedOptionalFields() {
        let payload = CreateAssignmentPayload(signers: [.id("s1")])
        let body = try! buildAssignmentBody(payload)
        XCTAssertNil(body.message)
        XCTAssertNil(body.expiresAt)
    }

    func testAcceptsDescriptorSignerObjects() {
        let payload = CreateAssignmentPayload(
            signers: [.descriptor(id: "s1", verificationMethod: "email", notificationMethods: ["email"])]
        )
        let body = try! buildAssignmentBody(payload)
        XCTAssertEqual(body.signers[0].id, "s1")
        XCTAssertEqual(body.signers[0].verificationMethod, "email")
    }

    func testAllowsEstimationPayloadsWithoutSignerIDs() {
        let payload = CreateAssignmentPayload(
            signers: [.descriptor(verificationMethod: "email")]
        )
        let body = try! buildAssignmentBody(payload, allowWithoutId: true)
        XCTAssertEqual(body.signers[0].verificationMethod, "email")
    }

    func testEstimateCostAcceptsSignerDescriptorsWithoutIDs() {
        let payload = CreateAssignmentPayload(
            signers: [.descriptor(verificationMethod: "email", notificationMethods: ["whatsapp"])]
        )
        let body = try! buildAssignmentBody(payload, allowWithoutId: true)
        XCTAssertEqual(body.signers[0].verificationMethod, "email")
        XCTAssertEqual(body.signers[0].notificationMethods, ["whatsapp"])
    }
}

final class AssignmentResourceTests: XCTestCase {
    var mock: MockHTTPClient!
    var resource: AssignmentResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        resource = AssignmentResource(http: mock, defaultAccountId: "test-account")
    }

    private func assignmentDict(id: String = "a1") -> [String: Any] {
        ["id": id, "method": "virtual", "signers": []]
    }

    func testCreatePostsToCorrectURL() async throws {
        mock.stubEnvelope(assignmentDict())
        _ = try await resource.create(documentId: "doc1", payload: .withSignerIds(["s1"]))
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1/assignments")
        XCTAssertEqual(mock.lastRequest?.method, .post)
    }

    func testCreateNormalisesSignerReferences() async throws {
        mock.stubEnvelope(assignmentDict())
        _ = try await resource.create(documentId: "doc1", payload: .withSignerIds(["s1", "s2"]))
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let signers = json["signers"] as? [[String: Any]] else {
            XCTFail("No request body")
            return
        }
        XCTAssertEqual(signers[0]["id"] as? String, "s1")
        XCTAssertEqual(signers[1]["id"] as? String, "s2")
    }

    func testResetExpirationCallsPutMethod() async throws {
        mock.stubEnvelope(assignmentDict())
        _ = try await resource.resetExpiration(documentId: "doc1", assignmentId: "a1")
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1/assignments/a1/reset-expiration")
    }

    func testResendNotificationRequiresDocumentAssignmentAndSignerID() async {
        await assertThrowsValidationError {
            _ = try await self.resource.resendNotification(documentId: "", assignmentId: "a1", signerId: "s1")
        }
        await assertThrowsValidationError {
            _ = try await self.resource.resendNotification(documentId: "doc1", assignmentId: "", signerId: "s1")
        }
    }

    func testResendNotificationUsesDocumentedSignerEndpoint() async throws {
        mock.stubEnvelope(["is_sent": true, "document_id": "doc1", "signer_id": "s1"])
        _ = try await resource.resendNotification(documentId: "doc1", assignmentId: "a1", signerId: "s1")
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1/assignments/a1/signers/s1/resend")
    }

    func testEstimateResendCostUsesDocumentedSignerEndpoint() async throws {
        mock.stubEnvelope(["total": 0])
        _ = try await resource.estimateResendCost(documentId: "doc1", assignmentId: "a1", signerId: "s1")
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1/assignments/a1/signers/s1/estimate-resend-cost")
    }

    func testEstimateCostAcceptsSignerDescriptorsWithoutIDs() async throws {
        mock.stubEnvelope(["total": 0])
        let payload = CreateAssignmentPayload(
            signers: [.descriptor(verificationMethod: "email")]
        )
        _ = try await resource.estimateCost(documentId: "doc1", payload: payload)
        XCTAssertEqual(mock.lastRequest?.method, .post)
    }

    func testEstimateCostReturnsTypedCostEstimate() async throws {
        mock.stubEnvelope([
            "credit_balance": 10.0,
            "document_balance": 5.0,
            "estimated_cost": 1.45,
            "has_sufficient_balance": true,
        ])
        let estimate = try await resource.estimateCost(
            documentId: "doc1",
            payload: .withSignerIds(["s1"])
        )
        XCTAssertEqual(estimate.creditBalance, 10.0)
        XCTAssertEqual(estimate.documentBalance, 5.0)
        XCTAssertEqual(estimate.estimatedCost, 1.45)
        XCTAssertTrue(estimate.hasSufficientBalance)
    }

    func testEstimateResendCostReturnsTypedCostEstimate() async throws {
        mock.stubEnvelope(["estimated_cost": "0.45"])
        let estimate = try await resource.estimateResendCost(
            documentId: "doc1",
            assignmentId: "a1",
            signerId: "s1"
        )
        XCTAssertEqual(estimate.estimatedCost, 0.45)
    }
}
