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

    func testCreateRequiresEmailOrWhatsapp() async {
        await assertThrowsValidationError {
            _ = try await self.resource.create(CreateSignerPayload(fullName: "Test"))
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

    func testCreateStripsCPFNonDigits() async throws {
        mock.stubEnvelopeList([])
        mock.stubEnvelope(signerDict(id: "123"))
        _ = try await resource.create(
            CreateSignerPayload(fullName: "John", email: "john@example.com", cpf: "123.456.789-00")
        )
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No request body")
            return
        }
        XCTAssertEqual(json["cpf"] as? String, "12345678900")
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
    }

    func testSignerDecodesDocumentAssignmentFields() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "id": "s1",
            "full_name": "Test",
            "email": NSNull(),
            "verification_method": "Whatsapp",
            "notification_methods": ["Whatsapp"],
            "completed": true,
            "notification_history": [
                ["event": "signature_requested", "status": "sent", "sent_at": "2026-05-04T15:00:00Z"]
            ],
        ])
        let signer = try JSONDecoder.assinafy.decode(Signer.self, from: data)
        XCTAssertNil(signer.email)
        XCTAssertEqual(signer.verificationMethod, "Whatsapp")
        XCTAssertEqual(signer.notificationMethods, ["Whatsapp"])
        XCTAssertTrue(signer.completed)
        XCTAssertEqual(signer.notificationHistory.first?.event, "signature_requested")
    }

    // MARK: - Signer-facing document endpoints

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

    func testListSignerDocumentsForwardsFilters() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.listSignerDocuments(
            signerId: "s1",
            signerAccessCode: "code",
            params: SignerDocumentListParams(status: "pending_signature", method: "virtual", search: "abc", sort: "name")
        )
        let pairs = (mock.lastRequest?.queryItems ?? []).reduce(into: [String: String]()) { acc, item in
            acc[item.name] = item.value
        }
        XCTAssertEqual(pairs["status"], "pending_signature")
        XCTAssertEqual(pairs["method"], "virtual")
        XCTAssertEqual(pairs["search"], "abc")
        XCTAssertEqual(pairs["sort"], "name")
        XCTAssertEqual(pairs["signer-access-code"], "code")
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

    func testDownloadSignerArtifactBuildsCorrectPath() async throws {
        mock.stub(response: APIResponse(data: Data([0xFF]), headers: [:], statusCode: 200))
        _ = try await resource.downloadSignerDocumentArtifact(
            signerId: "s1",
            documentId: "d1",
            artifact: .certificated,
            signerAccessCode: "code"
        )
        XCTAssertEqual(mock.lastRequest?.path, "/signers/s1/documents/d1/download/certificated")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.value, "code")
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
