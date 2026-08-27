import XCTest
@testable import Assinafy

final class AssignmentPayloadTests: XCTestCase {

    private var settings: DisplaySettings {
        DisplaySettings(
            left: 10,
            top: 20,
            width: 180,
            height: 40,
            fontFamily: "Arial",
            fontSize: 16,
            backgroundColor: "#D5EBFF"
        )
    }

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
        let field = AssignmentField(signerId: "s1", fieldId: "f1", displaySettings: settings)
        let entry = AssignmentEntry(pageId: "p1", fields: [field])
        let payload = CreateAssignmentPayload(method: .collect, signers: [.id("s1")], entries: [entry])
        let body = try! buildAssignmentBody(payload)
        XCTAssertEqual(body.entries?.count, 1)
        XCTAssertEqual(body.entries?[0].pageId, "p1")
        XCTAssertEqual(body.entries?[0].fields[0].signerId, "s1")
        XCTAssertEqual(body.entries?[0].fields[0].displaySettings?.left, 10)

        let data = try! JSONEncoder.assinafy.encode(body)
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let entries = json["entries"] as! [[String: Any]]
        let fields = entries[0]["fields"] as! [[String: Any]]
        let encodedSettings = fields[0]["display_settings"] as? [String: Any]
        XCTAssertEqual(encodedSettings?["fontSize"] as? Double, 16)
        XCTAssertEqual(encodedSettings?["backgroundColor"] as? String, "#D5EBFF")
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
        let body = try! buildAssignmentEstimateBody(payload)
        XCTAssertEqual(body.signers?[0].verificationMethod, "email")
    }

    func testEstimateCostAcceptsSignerDescriptorsWithoutIDs() {
        let payload = CreateAssignmentPayload(
            signers: [.descriptor(verificationMethod: "email", notificationMethods: ["whatsapp"])]
        )
        let body = try! buildAssignmentEstimateBody(payload)
        XCTAssertEqual(body.signers?[0].verificationMethod, "email")
        XCTAssertEqual(body.signers?[0].notificationMethods, ["whatsapp"])
    }

    func testCreateRejectsDescriptorWithoutSignerID() {
        let payload = CreateAssignmentPayload(
            signers: [.descriptor(verificationMethod: "Email", notificationMethods: ["Email"])]
        )
        XCTAssertThrowsError(try buildAssignmentBody(payload)) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }

    func testCollectEstimateDoesNotRequireSigners() throws {
        let field = AssignmentField(signerId: "s1", fieldId: "f1", displaySettings: settings)
        let payload = CreateAssignmentPayload(
            method: .collect,
            signers: [],
            entries: [AssignmentEntry(pageId: "p1", fields: [field])]
        )
        let body = try buildAssignmentEstimateBody(payload)
        XCTAssertNil(body.signers)
        XCTAssertEqual(body.entries?.count, 1)
    }

    func testRejectsInvalidDisplaySettingsGeometry() {
        let invalid = DisplaySettings(left: 0, top: 0, width: 0, height: 20, fontSize: 12)
        let field = AssignmentField(signerId: "s1", fieldId: "f1", displaySettings: invalid)
        let payload = CreateAssignmentPayload(
            method: .collect,
            signers: [.id("s1")],
            entries: [AssignmentEntry(pageId: "p1", fields: [field])]
        )
        XCTAssertThrowsError(try buildAssignmentBody(payload)) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }

    func testRejectsWhitespaceCollectIdentifiers() {
        let blankPage = CreateAssignmentPayload(
            method: .collect,
            signers: [.id("s1")],
            entries: [AssignmentEntry(pageId: "  ", fields: [
                AssignmentField(signerId: "s1", fieldId: "f1")
            ])]
        )
        XCTAssertThrowsError(try buildAssignmentBody(blankPage))

        let blankSigner = CreateAssignmentPayload(
            method: .collect,
            signers: [.id("s1")],
            entries: [AssignmentEntry(pageId: "p1", fields: [
                AssignmentField(signerId: "\n", fieldId: "f1")
            ])]
        )
        XCTAssertThrowsError(try buildAssignmentBody(blankSigner))
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
        ["resource": "assignment", "id": id, "method": "virtual", "signers": []]
    }

    func testListUsesOnlyDocumentedPaginationWithoutRequiringAccount() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.list(params: ListParams(page: 2, perPage: 25))
        XCTAssertEqual(mock.lastRequest?.path, "/assignments")
        let query = (mock.lastRequest?.queryItems ?? []).reduce(into: [String: String]()) {
            if let value = $1.value { $0[$1.name] = value }
        }
        XCTAssertEqual(query["page"], "2")
        XCTAssertEqual(query["per-page"], "25")
        XCTAssertNil(query["accountId"])
        XCTAssertNil(query["account_id"])
    }

    func testListPreservesLegacyDefaultArguments() async throws {
        let accountlessResource = AssignmentResource(http: mock)
        mock.stubEnvelopeList([])
        _ = try await accountlessResource.list()
        XCTAssertNil(mock.lastRequest?.queryItems)

        mock.stubEnvelopeList([])
        _ = try await accountlessResource.list(accountId: "account-1")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.name, "accountId")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.value, "account-1")
    }

    func testCreatePostsToCorrectURL() async throws {
        mock.stubEnvelope(assignmentDict())
        let assignment = try await resource.create(documentId: "doc1", payload: .withSignerIds(["s1"]))
        XCTAssertEqual(assignment.resource, "assignment")
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

    func testCreateRejectsDescriptorWithoutSignerIDBeforeRequest() async {
        await assertThrowsValidationError {
            _ = try await self.resource.create(
                documentId: "doc1",
                payload: CreateAssignmentPayload(
                    signers: [.descriptor(verificationMethod: "Email")]
                )
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testResetExpirationCallsPutMethod() async throws {
        mock.stubEnvelope(assignmentDict())
        _ = try await resource.resetExpiration(documentId: "doc1", assignmentId: "a1")
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1/assignments/a1/reset-expiration")
    }

    func testCanonicalResetExpirationRequiresAndEncodesDate() async throws {
        mock.stubEnvelope(assignmentDict())
        let expiration = "2026-09-03T12:00:00Z"

        _ = try await resource.resetExpiration(
            documentId: "doc1",
            assignmentId: "a1",
            newExpiresAt: expiration
        )

        let data = try XCTUnwrap(mock.lastRequest?.body)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body["expires_at"] as? String, expiration)

        await assertThrowsValidationError {
            _ = try await self.resource.resetExpiration(
                documentId: "doc1",
                assignmentId: "a1",
                newExpiresAt: "  "
            )
        }
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

    func testEstimateCostSendsOnlyEstimateContractFields() async throws {
        mock.stubEnvelope(["total_credits": 0])
        let payload = CreateAssignmentPayload(
            method: .virtual,
            signers: [
                .descriptor(
                    id: "signer-id-must-not-be-sent",
                    verificationMethod: "Whatsapp",
                    notificationMethods: ["Email", "Whatsapp"],
                    step: 2
                )
            ],
            message: "creation-only",
            expiresAt: "2027-01-01T00:00:00Z",
            copyReceivers: ["copy-id"]
        )
        _ = try await resource.estimateCost(documentId: "doc1", payload: payload)
        let body = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["method", "signers"])
        let signer = try XCTUnwrap((json["signers"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(signer.keys), ["verification_method", "notification_methods"])
        XCTAssertNil(signer["id"])
        XCTAssertNil(signer["step"])
        XCTAssertNil(json["message"])
        XCTAssertNil(json["expires_at"])
        XCTAssertNil(json["copy_receivers"])
    }

    func testEstimateCostReturnsTypedCostEstimate() async throws {
        mock.stubEnvelope([
            "credit_balance": 10.0,
            "document_balance": 5.0,
            "credits": 0.45,
            "total_credits": 1.45,
            "needs_extra_document": true,
            "extra_document_cost": 1.0,
            "has_sufficient_resources": true,
        ])
        let estimate = try await resource.estimateCost(
            documentId: "doc1",
            payload: .withSignerIds(["s1"])
        )
        XCTAssertEqual(estimate.creditBalance, 10.0)
        XCTAssertEqual(estimate.documentBalance, 5.0)
        XCTAssertEqual(estimate.estimatedCost, 1.45)
        XCTAssertTrue(estimate.hasSufficientBalance)
        XCTAssertEqual(estimate.credits, 0.45)
        XCTAssertEqual(estimate.totalCredits, 1.45)
        XCTAssertTrue(estimate.needsExtraDocument)
        XCTAssertEqual(estimate.extraDocumentCost, 1.0)
        XCTAssertTrue(estimate.hasSufficientResources)
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

    func testAssignmentDecodesCopyReceiversAsSignerObjects() async throws {
        mock.stubEnvelope([
            "id": "a1",
            "method": "virtual",
            "signers": [],
            "copy_receivers": [
                ["id": "s2", "full_name": "Eric Flores", "email": "eric@example.com"],
            ],
        ])
        let assignment = try await resource.create(
            documentId: "doc1",
            payload: .withSignerIds(["s1"])
        )
        XCTAssertEqual(assignment.copyReceivers.count, 1)
        XCTAssertEqual(assignment.copyReceivers.first?.id, "s2")
        XCTAssertEqual(assignment.copyReceivers.first?.fullName, "Eric Flores")
    }

    func testAssignmentTolerantOfMissingCopyReceivers() async throws {
        mock.stubEnvelope(assignmentDict())
        let assignment = try await resource.create(
            documentId: "doc1",
            payload: .withSignerIds(["s1"])
        )
        XCTAssertTrue(assignment.copyReceivers.isEmpty)
    }

    /// The documented collect-assignment create response returns `"method": null`;
    /// decoding must not throw and should default to `.virtual`.
    func testAssignmentDecodesNullMethodAsVirtual() async throws {
        mock.stubEnvelope(["id": "a1", "method": NSNull(), "signers": []])
        let assignment = try await resource.create(
            documentId: "doc1",
            payload: .withSignerIds(["s1"])
        )
        XCTAssertEqual(assignment.method, .virtual)
        XCTAssertEqual(assignment.methodString, "virtual")
    }

    /// The published docs examples use the `expiration` key while the live API
    /// uses `expires_at`; both must populate ``Assignment/expiresAt``.
    func testAssignmentDecodesExpirationKeyFallback() async throws {
        mock.stubEnvelope([
            "id": "a1",
            "method": "virtual",
            "signers": [],
            "expiration": "2026-01-01T00:00:00Z",
        ])
        let assignment = try await resource.create(
            documentId: "doc1",
            payload: .withSignerIds(["s1"])
        )
        XCTAssertEqual(assignment.expiresAt, "2026-01-01T00:00:00Z")
    }

    /// `expires_at` (live API) takes precedence and is decoded as-is.
    func testAssignmentDecodesExpiresAtKey() async throws {
        mock.stubEnvelope([
            "id": "a1",
            "method": "virtual",
            "signers": [],
            "expires_at": "2026-02-02T00:00:00Z",
        ])
        let assignment = try await resource.create(
            documentId: "doc1",
            payload: .withSignerIds(["s1"])
        )
        XCTAssertEqual(assignment.expiresAt, "2026-02-02T00:00:00Z")
    }

    func testSignPostsToAssignmentEndpointWithAccessCode() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.sign(
            documentId: "doc1",
            assignmentId: "a1",
            signerAccessCode: "code-123",
            fields: [SignAssignmentField(itemId: "i1", fieldId: "fd1", pageId: "p1", value: "Signed")]
        )
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1/assignments/a1")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.name, "signer-access-code")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.value, "code-123")
        guard let body = mock.lastRequest?.body,
              let arr = try? JSONSerialization.jsonObject(with: body) as? [[String: Any]] else {
            XCTFail("Expected array body")
            return
        }
        XCTAssertEqual(arr.first?["itemId"] as? String, "i1")
        XCTAssertEqual(arr.first?["fieldId"] as? String, "fd1")
    }

    func testSignAllowsEmptyFieldsForVirtual() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.sign(
            documentId: "doc1",
            assignmentId: "a1",
            signerAccessCode: "code",
            fields: []
        )
        guard let body = mock.lastRequest?.body else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(String(data: body, encoding: .utf8), "[]")
    }

    func testSignRequiresAccessCode() async {
        await assertThrowsValidationError {
            try await self.resource.sign(documentId: "doc1", assignmentId: "a1", signerAccessCode: "")
        }
    }

    func testSignValidatesEveryRequiredFieldBeforeRequest() async {
        let invalidFields = [
            SignAssignmentField(itemId: "", fieldId: "field", pageId: "page", value: "value"),
            SignAssignmentField(itemId: "item", fieldId: "", pageId: "page", value: "value"),
            SignAssignmentField(itemId: "item", fieldId: "field", pageId: nil, value: "value"),
            SignAssignmentField(itemId: "item", fieldId: "field", pageId: "", value: "value"),
        ]
        for field in invalidFields {
            do {
                try await resource.sign(
                    documentId: "doc1",
                    assignmentId: "a1",
                    signerAccessCode: "code",
                    fields: [field]
                )
                XCTFail("Expected ValidationError")
            } catch is ValidationError {
            } catch {
                XCTFail("Expected ValidationError, got \(type(of: error))")
            }
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testDeclineSendsRejectEndpoint() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.decline(
            documentId: "doc1",
            assignmentId: "a1",
            signerAccessCode: "code",
            reason: "Not happy"
        )
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1/assignments/a1/reject")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.value, "code")
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["decline_reason"] as? String, "Not happy")
    }

    func testDeclineRejectsBlankReasonBeforeRequest() async {
        await assertThrowsValidationError {
            try await self.resource.decline(
                documentId: "doc1",
                assignmentId: "assignment1",
                signerAccessCode: "code",
                reason: "  "
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testListWhatsappNotificationsDecodesButtons() async throws {
        mock.stubEnvelopeList([
            [
                "sent_at": 1710000000,
                "header": "Documento para assinatura",
                "body": "Texto",
                "buttons": [["text": "Abrir documento"]],
                "phone_number": "+5511999990001",
                "signer_id": "s1",
            ]
        ])
        let result = try await resource.listWhatsappNotifications(documentId: "doc1", assignmentId: "a1")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.sentAt, 1710000000)
        XCTAssertEqual(result.first?.buttonTexts, ["Abrir documento"])
        XCTAssertEqual(mock.lastRequest?.path,
                       "/documents/doc1/assignments/a1/whatsapp-notifications")
    }

    func testCreateAssignmentSendsCopyReceiverIDsAsStrings() async throws {
        mock.stubEnvelope(assignmentDict())
        let payload = CreateAssignmentPayload.withSignerIds(
            ["s1"],
            copyReceivers: ["s2", "s3"]
        )
        _ = try await resource.create(documentId: "doc1", payload: payload)
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No request body")
            return
        }
        XCTAssertEqual(json["copy_receivers"] as? [String], ["s2", "s3"])
    }
}
