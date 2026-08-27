import XCTest
@testable import Assinafy

final class SignerResourceTests: XCTestCase {
    var mock: MockHTTPClient!
    var resource: SignerResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        resource = SignerResource(http: mock, defaultAccountId: "test-account")
    }

    private func signerDict(id: String = "1", name: String = "Test", email: String = "test@test.com") -> [String: Any] {
        ["id": id, "full_name": name, "email": email]
    }

    // MARK: - Validation

    func testThrowsWhenUpdatingWithoutSignerID() async {
        await assertThrowsValidationError {
            _ = try await self.resource.update(signerId: "", payload: UpdateSignerPayload(fullName: "Test"))
        }
    }

    func testThrowsWhenDeletingWithoutSignerID() async {
        await assertThrowsValidationError {
            try await self.resource.delete(signerId: "")
        }
    }

    func testThrowsWhenNoAccountIDAvailable() async {
        let noAccount = SignerResource(http: mock, defaultAccountId: nil)
        await assertThrowsValidationError {
            _ = try await noAccount.create(
                CreateSignerPayload(fullName: "Test", email: "test@test.com")
            )
        }
    }

    func testRejectsInvalidEmail() async {
        await assertThrowsValidationError {
            _ = try await self.resource.create(
                CreateSignerPayload(fullName: "Test", email: "not-an-email")
            )
        }
        await assertThrowsValidationError {
            _ = try await self.resource.create(
                CreateSignerPayload(fullName: "Test", email: " test@example.com ")
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testRejectsEmptyEmail() async {
        await assertThrowsValidationError {
            _ = try await self.resource.create(
                CreateSignerPayload(fullName: "Test", email: "")
            )
        }
    }

    func testCreateAllowsWhatsappOnlySigner() async throws {
        mock.stubEnvelope(signerDict(id: "123", email: ""))
        _ = try await resource.create(
            CreateSignerPayload(fullName: "John", whatsappPhoneNumber: "+5548999990000")
        )
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/signers")
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No request body")
            return
        }
        XCTAssertNil(json["email"])
        XCTAssertEqual(json["whatsapp_phone_number"] as? String, "+5548999990000")
    }

    func testCreateAllowsDocumentedFullNameOnlyPayload() async throws {
        mock.stubEnvelope(signerDict())

        _ = try await resource.create(CreateSignerPayload(fullName: "Test"))

        let data = try XCTUnwrap(mock.lastRequest?.body)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body.count, 1)
        XCTAssertEqual(body["full_name"] as? String, "Test")
    }

    func testValidateCreatePayloadRejectsBlankFullNameSynchronously() {
        XCTAssertThrowsError(try resource.validateCreatePayload(CreateSignerPayload(fullName: "  \n"))) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }

    // MARK: - Create

    func testUsesCustomAccountIDWhenProvided() async throws {
        mock.stubEnvelopeList([])
        mock.stubEnvelope(signerDict(id: "123"))
        _ = try await resource.create(
            CreateSignerPayload(fullName: "Test", email: "test@test.com"),
            accountId: "custom-account"
        )
        XCTAssertTrue(mock.allRequests.contains { $0.path == "/accounts/custom-account/signers" })
    }

    func testCreateReuseExistingSignerByEmail() async throws {
        mock.stubEnvelopeList([signerDict(id: "existing", email: "john@example.com")])
        let result = try await resource.create(
            CreateSignerPayload(fullName: "John", email: "john@example.com")
        )
        XCTAssertEqual(result.id, "existing")
        XCTAssertEqual(mock.lastRequest?.method, .get, "Should reuse existing — no POST expected")
    }

    func testCreateSendsWhatsappPhoneNumber() async throws {
        mock.stubEnvelopeList([])
        mock.stubEnvelope(signerDict(id: "123"))
        _ = try await resource.create(
            CreateSignerPayload(fullName: "John", email: "john@example.com", whatsappPhoneNumber: "+5548999990000")
        )
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No request body")
            return
        }
        XCTAssertEqual(json["whatsapp_phone_number"] as? String, "+5548999990000")
    }

    func testCreateOmitsUnsupportedCPFField() async throws {
        // The live API silently ignores `cpf`/`government_id` on signer create,
        // so the payload must not send them.
        mock.stubEnvelopeList([])
        mock.stubEnvelope(signerDict(id: "123"))
        _ = try await resource.create(
            CreateSignerPayload(fullName: "John", email: "john@example.com")
        )
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No request body")
            return
        }
        XCTAssertNil(json["cpf"])
        XCTAssertNil(json["government_id"])
        XCTAssertEqual(json["full_name"] as? String, "John")
    }

    // MARK: - List

    func testListPassesSearchViaQueryItems() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.list(params: ListParams(perPage: 25, search: "john@example.com"))
        let queryItems = mock.lastRequest?.queryItems
        XCTAssertTrue(queryItems?.contains(URLQueryItem(name: "search", value: "john@example.com")) == true)
        XCTAssertTrue(queryItems?.contains(URLQueryItem(name: "per-page", value: "25")) == true)
    }

    func testListReturnsPaginationMeta() async throws {
        let headers = MockHTTPClient.paginationHeaders(currentPage: 2, perPage: 20, total: 45, pageCount: 3)
        mock.stubEnvelopeList([], headers: headers)
        let result = try await resource.list(params: ListParams(page: 2))
        XCTAssertEqual(result.meta?.currentPage, 2)
        XCTAssertEqual(result.meta?.perPage, 20)
        XCTAssertEqual(result.meta?.total, 45)
        XCTAssertEqual(result.meta?.lastPage, 3)
    }

    // MARK: - findByEmail

    func testFindByEmailReturnsNilWhenNoMatch() async throws {
        mock.stubEnvelopeList([])
        let result = try await resource.findByEmail("nobody@example.com")
        XCTAssertNil(result)
    }

    func testFindByEmailReturnsCaseInsensitiveMatch() async throws {
        mock.stubEnvelopeList([signerDict(id: "1", email: "JOHN@EXAMPLE.COM")])
        let result = try await resource.findByEmail("john@example.com")
        XCTAssertEqual(result?.id, "1")
    }

    func testFindByEmailRequiresValidEmail() async {
        await assertThrowsValidationError {
            _ = try await self.resource.findByEmail("not-an-email")
        }
    }

    // MARK: - Get / Update / Delete paths

    func testGetUsesCorrectPath() async throws {
        mock.stubEnvelope(signerDict(id: "s1"))
        _ = try await resource.get(signerId: "s1")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/signers/s1")
        XCTAssertEqual(mock.lastRequest?.method, .get)
    }

    func testUpdateUsesCorrectPath() async throws {
        mock.stubEnvelope(signerDict(id: "s1", name: "Updated"))
        _ = try await resource.update(signerId: "s1", payload: UpdateSignerPayload(fullName: "Updated"))
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/signers/s1")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testUpdateEncodesGovernmentId() async throws {
        mock.stubEnvelope(signerDict(id: "s1"))

        _ = try await resource.update(
            signerId: "s1",
            payload: UpdateSignerPayload(governmentId: "39053344705")
        )

        let data = try XCTUnwrap(mock.lastRequest?.body)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body.count, 1)
        XCTAssertEqual(body["government_id"] as? String, "39053344705")
    }

    func testDeleteUsesCorrectPath() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 204))
        try await resource.delete(signerId: "s1")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/signers/s1")
        XCTAssertEqual(mock.lastRequest?.method, .delete)
    }

    // MARK: - Display

    func testSignerDescriptionIsReadable() {
        let signer = Signer(id: "1", fullName: "Test", email: "t@t.com")
        XCTAssertFalse(signer.description.isEmpty)
        XCTAssertFalse(signer.description.contains("t@t.com"))
    }

    func testSignerDecodesDocumentAssignmentFields() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "resource": "signer",
            "id": "s1",
            "full_name": "Test",
            "email": NSNull(),
            "verification_method": "Whatsapp",
            "notification_methods": ["Whatsapp"],
            "notified": true,
            "completed": true,
            "notification_history": [
                ["event": "signature_requested", "status": "sent", "sent_at": "2026-05-04T15:00:00Z"]
            ],
        ])
        let signer = try JSONDecoder.assinafy.decode(Signer.self, from: data)
        XCTAssertEqual(signer.resource, "signer")
        XCTAssertNil(signer.email)
        XCTAssertEqual(signer.verificationMethod, "Whatsapp")
        XCTAssertEqual(signer.notificationMethods, ["Whatsapp"])
        XCTAssertEqual(signer.notified?.boolValue, true)
        XCTAssertTrue(signer.completed)
        XCTAssertEqual(signer.notificationHistory.first?.event, "signature_requested")
    }

    // MARK: - Signer-facing document endpoints

    func testGetSelfDecodesSignatureReuseFlag() async throws {
        mock.stubEnvelope([
            "resource": "signer",
            "id": "s1",
            "full_name": "Signer",
            "has_signature": true,
            "has_initial": false,
            "is_signature_reusable": true,
        ])

        let result = try await resource.getSelf(signerAccessCode: "code")

        XCTAssertEqual(result.resource, "signer")
        XCTAssertTrue(result.hasSignature)
        XCTAssertTrue(result.isSignatureReusable)
        XCTAssertEqual(mock.lastRequest?.queryItems, [
            URLQueryItem(name: "signer-access-code", value: "code")
        ])
    }

    func testAcceptTermsUsesQueryAndHandlesBareEnvelope() async throws {
        mock.stubJSON(["status": 200, "message": "Accepted"])

        let result = try await resource.acceptTerms(signerAccessCode: "code")

        XCTAssertTrue(result.hasAcceptedTerms)
        XCTAssertEqual(result.fullName, "")
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/signers/accept-terms")
        XCTAssertNil(mock.lastRequest?.body)
        XCTAssertEqual(mock.lastRequest?.queryItems, [
            URLQueryItem(name: "signer-access-code", value: "code")
        ])
    }

    func testAcceptTermsStillDecodesLegacyResponseData() async throws {
        mock.stubEnvelope([
            "full_name": "Signer",
            "email": "signer@example.com",
            "has_accepted_terms": true,
        ])

        let result = try await resource.acceptTerms(signerAccessCode: "code")

        XCTAssertEqual(result.fullName, "Signer")
        XCTAssertEqual(result.email, "signer@example.com")
    }

    func testAcceptTermsStillDecodesLegacyDirectResponse() async throws {
        mock.stubJSON([
            "full_name": "Signer",
            "email": "signer@example.com",
            "has_accepted_terms": true,
        ])

        let result = try await resource.acceptTerms(signerAccessCode: "code")

        XCTAssertEqual(result.fullName, "Signer")
        XCTAssertTrue(result.hasAcceptedTerms)
    }

    func testVerifyEmailUsesQueryAndExactBody() async throws {
        mock.stubJSON(["status": 200, "message": "Verified"])

        try await resource.verifyEmail(
            payload: VerifyEmailPayload(verificationCode: "123456", signerAccessCode: "code")
        )

        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/verify")
        XCTAssertEqual(mock.lastRequest?.queryItems, [
            URLQueryItem(name: "signer-access-code", value: "code")
        ])
        let data = try XCTUnwrap(mock.lastRequest?.body)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body.count, 1)
        XCTAssertEqual(body["verification-code"] as? String, "123456")
    }

    func testDownloadSignatureDoesNotRepeatTypeAsQuery() async throws {
        mock.stub(response: APIResponse(data: Data([0x89]), headers: [:], statusCode: 200))

        _ = try await resource.downloadSignature(signerAccessCode: "code", type: .initial)

        XCTAssertEqual(mock.lastRequest?.path, "/signature/initial")
        XCTAssertEqual(mock.lastRequest?.queryItems, [
            URLQueryItem(name: "signer-access-code", value: "code")
        ])
    }

    func testGetCurrentDocumentUsesSignerEndpoint() async throws {
        mock.stubEnvelope([
            "id": "doc1",
            "account_id": "acc1",
            "name": "test.pdf",
            "status": "metadata_ready",
            "pages": [],
            "created_at": "2024-01-01",
            "updated_at": "2024-01-01",
        ])
        _ = try await resource.getCurrentDocument(signerId: "s1", signerAccessCode: "code")
        XCTAssertEqual(mock.lastRequest?.path, "/signers/s1/document")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.name, "signer-access-code")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.value, "code")
    }

    func testListSignerDocumentsPreservesLegacyFiltersWithPagination() async throws {
        mock.stubEnvelopeList([])
        let params = SignerDocumentListParams(
            status: "pending_signature",
            method: "virtual",
            search: "legacy",
            sort: "name"
        )
        params.page = 2
        params.perPage = 25
        _ = try await resource.listSignerDocuments(
            signerId: "s1",
            signerAccessCode: "code",
            params: params
        )
        let pairs = (mock.lastRequest?.queryItems ?? []).reduce(into: [String: String]()) { acc, item in
            acc[item.name] = item.value
        }
        XCTAssertEqual(pairs["status"], "pending_signature")
        XCTAssertEqual(pairs["method"], "virtual")
        XCTAssertEqual(pairs["search"], "legacy")
        XCTAssertEqual(pairs["sort"], "name")
        XCTAssertEqual(pairs["page"], "2")
        XCTAssertEqual(pairs["per-page"], "25")
        XCTAssertEqual(pairs["signer-access-code"], "code")
    }

    func testSearchSignerDocumentsPreservesLegacyStatus() async throws {
        mock.stubEnvelopeList([])

        _ = try await resource.searchSignerDocuments(
            signerId: "s1",
            signerAccessCode: "code",
            search: "contract",
            status: "pending_signature"
        )

        let pairs = (mock.lastRequest?.queryItems ?? []).reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }
        XCTAssertEqual(pairs["search"], "contract")
        XCTAssertEqual(pairs["status"], "pending_signature")
    }

    func testSignMultipleSendsArrayOfIDs() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.signMultipleDocuments(
            signerAccessCode: "code",
            documentIds: ["d1", "d2"]
        )
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/signers/documents/sign-multiple")
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["document_ids"] as? [String], ["d1", "d2"])
    }

    func testSignMultipleRejectsEmpty() async {
        await assertThrowsValidationError {
            try await self.resource.signMultipleDocuments(signerAccessCode: "c", documentIds: [])
        }
    }

    func testDeclineMultipleEncodesReason() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.declineMultipleDocuments(
            signerAccessCode: "code",
            documentIds: ["d1"],
            reason: "Bad terms"
        )
        XCTAssertEqual(mock.lastRequest?.path, "/signers/documents/decline-multiple")
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["document_ids"] as? [String], ["d1"])
        XCTAssertEqual(json["decline_reason"] as? String, "Bad terms")
    }

    func testBatchOperationsValidateEveryDocumentIDAndDeclineReason() async {
        await assertThrowsValidationError {
            try await self.resource.signMultipleDocuments(
                signerAccessCode: "code",
                documentIds: ["valid", "../invalid"]
            )
        }
        await assertThrowsValidationError {
            try await self.resource.declineMultipleDocuments(
                signerAccessCode: "code",
                documentIds: ["valid"],
                reason: "  "
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testUploadSignatureRejectsNonPNGDataBeforeRequest() async {
        await assertThrowsValidationError {
            try await self.resource.uploadSignature(
                signerAccessCode: "code",
                type: .signature,
                imageData: Data("not-png".utf8)
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testAcceptTermsWithoutResponseUsesBareEnvelope() async throws {
        mock.stubJSON(["status": 200, "message": "Accepted"])
        try await resource.acceptTermsWithoutResponse(signerAccessCode: "code")
        XCTAssertEqual(mock.lastRequest?.path, "/signers/accept-terms")
        XCTAssertEqual(
            mock.lastRequest?.queryItems,
            [URLQueryItem(name: "signer-access-code", value: "code")]
        )
    }

    func testDownloadSignerArtifactBuildsCorrectPath() async throws {
        mock.stub(response: APIResponse(data: Data([0xFF]), headers: [:], statusCode: 200))
        _ = try await resource.downloadSignerDocumentArtifact(
            signerId: "s1",
            documentId: "d1",
            artifact: .certificated
        )
        XCTAssertEqual(mock.lastRequest?.path, "/signers/s1/documents/d1/download/certificated")
        XCTAssertNil(mock.lastRequest?.queryItems)
    }

    func testLegacySignerArtifactAccessCodeIsNotSent() async throws {
        mock.stub(response: APIResponse(data: Data([0xFF]), headers: [:], statusCode: 200))

        _ = try await resource.downloadSignerDocumentArtifact(
            signerId: "s1",
            documentId: "d1",
            artifact: .original,
            signerAccessCode: "legacy-code"
        )

        XCTAssertNil(mock.lastRequest?.queryItems)
    }

    func testGetSigningDocumentUsesGenericSignEndpoint() async throws {
        mock.stubEnvelope([
            "id": "doc1",
            "account_id": "acc1",
            "name": "test.pdf",
            "status": "pending_signature",
            "pages": [],
            "created_at": "2024-01-01",
            "updated_at": "2024-01-01",
        ])
        _ = try await resource.getSigningDocument(signerAccessCode: "code", hasAcceptedTerms: true)
        XCTAssertEqual(mock.lastRequest?.path, "/sign")
        let pairs = (mock.lastRequest?.queryItems ?? []).reduce(into: [String: String]()) { acc, item in
            acc[item.name] = item.value
        }
        XCTAssertEqual(pairs["signer-access-code"], "code")
        XCTAssertEqual(pairs["has_accepted_terms"], "true")
    }
}
