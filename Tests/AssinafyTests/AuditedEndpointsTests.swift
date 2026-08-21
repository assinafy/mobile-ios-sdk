import XCTest
@testable import Assinafy

/// Unit coverage for the endpoints and payload corrections introduced by the
/// API audit. Each test pins the HTTP method, path, and request body against the
/// live-verified contract so regressions are caught without network access.
final class AuditedEndpointsTests: XCTestCase {
    var mock: MockHTTPClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
    }

    private func body(_ request: APIRequest?) -> [String: Any] {
        guard let data = request?.body,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }

    // MARK: - Documents

    func testDocumentRenameUsesPatchAndNameBody() async throws {
        let resource = DocumentResource(http: mock, defaultAccountId: "acc")
        mock.stubEnvelope([
            "id": "doc1", "account_id": "acc", "name": "New.pdf",
            "status": "metadata_ready", "pages": [],
            "created_at": "2026-01-01", "updated_at": "2026-01-01",
        ])
        _ = try await resource.rename(documentId: "doc1", name: "New.pdf")
        XCTAssertEqual(mock.lastRequest?.method, .patch)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1")
        XCTAssertEqual(body(mock.lastRequest)["name"] as? String, "New.pdf")
    }

    func testDocumentRenameRequiresName() async {
        let resource = DocumentResource(http: mock, defaultAccountId: "acc")
        await assertThrowsValidationError {
            _ = try await resource.rename(documentId: "doc1", name: "")
        }
    }

    func testDocumentSearchUsesSearchEndpoint() async throws {
        let resource = DocumentResource(http: mock, defaultAccountId: "acc")
        mock.stubEnvelopeList([])
        _ = try await resource.search(search: "contract", status: "metadata_ready")
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/documents/search")
        let items = mock.lastRequest?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "search", value: "contract")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "status", value: "metadata_ready")))
    }

    // MARK: - Assignments

    func testAssignmentListPreservesSandboxAccountContext() async throws {
        let resource = AssignmentResource(
            http: mock,
            defaultAccountId: "acc",
            usesSandboxCompatibility: true
        )
        mock.stubEnvelopeList([])
        _ = try await resource.list(params: ListParams(page: 2, perPage: 10))
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/assignments")
        let items = mock.lastRequest?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "accountId", value: "acc")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "page", value: "2")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "per-page", value: "10")))
    }

    func testAssignmentCreateEncodesSignerStep() throws {
        let payload = CreateAssignmentPayload(
            signers: [.descriptor(id: "s1", verificationMethod: "Email", notificationMethods: ["Email"], step: 2)]
        )
        let built = try buildAssignmentBody(payload)
        let data = try JSONEncoder.assinafy.encode(built)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let signers = try XCTUnwrap(json["signers"] as? [[String: Any]])
        XCTAssertEqual(signers.first?["step"] as? Int, 2)
        XCTAssertEqual(signers.first?["verification_method"] as? String, "Email")
    }

    // MARK: - Auth / Users

    func testCurrentUserUsesUsersSelf() async throws {
        let resource = AuthResource(http: mock, defaultAccountId: nil)
        mock.stubEnvelope([
            "user": ["id": "u1", "name": "Bill", "email": "bill@example.com",
                     "created_at": "2026-01-01", "is_password_set": true],
            "accounts": [["id": "a1", "name": "Acme", "roles": ["owner"],
                          "is_delete_allowed": true, "created_at": "2026-01-01"]],
        ])
        let me = try await resource.currentUser()
        XCTAssertEqual(mock.lastRequest?.path, "/users/self")
        XCTAssertEqual(me.user.id, "u1")
        XCTAssertTrue(me.user.isPasswordSet)
        XCTAssertEqual(me.accounts.first?.name, "Acme")
    }

    func testLinkSocialLoginPostsProviderAndToken() async throws {
        let resource = AuthResource(http: mock, defaultAccountId: nil)
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.linkSocialLogin(LinkSocialLoginPayload(provider: "google", token: "tok"))
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/auth/link-social-login")
        XCTAssertEqual(body(mock.lastRequest)["provider"] as? String, "google")
        XCTAssertEqual(body(mock.lastRequest)["token"] as? String, "tok")
    }

    func testUserStatsUsesUsersSelfStats() async throws {
        let resource = AuthResource(http: mock, defaultAccountId: nil)
        mock.stubEnvelopeList([])
        _ = try await resource.stats(params: AccountStatsParams(granularity: "daily", month: "2026-07"))
        XCTAssertEqual(mock.lastRequest?.path, "/users/self/stats")
        let items = mock.lastRequest?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "granularity", value: "daily")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "month", value: "2026-07")))
    }

    func testSocialLoginAuthorizationURL() {
        let client = AssinafyClient(apiKey: "k", defaultAccountId: "acc",
                                    baseURL: "https://sandbox.assinafy.com.br/v1")
        let url = client.socialLoginAuthorizationURL(authClient: "google")
        XCTAssertEqual(url?.absoluteString,
                       "https://sandbox.assinafy.com.br/v1/auth/authenticate?authclient=google")
    }

    // MARK: - Workspace logo & stats

    func testUploadLogoUsesMultipartPost() async throws {
        let resource = WorkspaceResource(http: mock, defaultAccountId: "acc")
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.uploadLogo(Data("png".utf8), filename: "logo.png", contentType: "image/png")
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/logo")
        XCTAssertTrue(mock.lastRequest?.contentType.hasPrefix("multipart/form-data") == true)
    }

    func testDeleteLogoUsesDelete() async throws {
        let resource = WorkspaceResource(http: mock, defaultAccountId: "acc")
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.deleteLogo()
        XCTAssertEqual(mock.lastRequest?.method, .delete)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/logo")
    }

    func testWorkspaceStatsUsesStatsEndpoint() async throws {
        let resource = WorkspaceResource(http: mock, defaultAccountId: "acc")
        mock.stubEnvelopeList([[
            "period": "2026-06",
            "documents_uploaded": 3,
            "documents_sent": 2,
            "signature_requests": 5,
            "signature_requests_notification_bypass": 1,
            "signature_requests_notification_email": 4,
            "signature_requests_notification_whatsapp": 2,
            "signature_requests_verification_bypass": 1,
            "signature_requests_verification_email": 2,
            "signature_requests_verification_whatsapp": 1,
            "signature_requests_verification_digital_certificate": 1,
            "signature_requests_viewed": 4,
            "signature_requests_completed": 3,
            "documents_certified": 2,
        ]])
        let rows = try await resource.stats(params: AccountStatsParams(granularity: "monthly"))
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/stats")
        XCTAssertEqual(rows.first?.period, "2026-06")
        XCTAssertEqual(rows.first?.documentsUploaded, 3)
        XCTAssertEqual(rows.first?.signatureRequestsNotificationBypass, 1)
        XCTAssertEqual(rows.first?.signatureRequestsNotificationEmail, 4)
        XCTAssertEqual(rows.first?.signatureRequestsNotificationWhatsapp, 2)
        XCTAssertEqual(rows.first?.signatureRequestsVerificationBypass, 1)
        XCTAssertEqual(rows.first?.signatureRequestsVerificationEmail, 2)
        XCTAssertEqual(rows.first?.signatureRequestsVerificationWhatsapp, 1)
        XCTAssertEqual(rows.first?.signatureRequestsVerificationDigitalCertificate, 1)
        XCTAssertEqual(rows.first?.signatureRequestsViewed, 4)
        XCTAssertEqual(rows.first?.signatureRequestsCompleted, 3)
        XCTAssertEqual(rows.first?.documentsCertified, 2)
    }

    func testCostEstimateDecodesDocumentedTypedBreakdown() throws {
        let json: [String: Any] = [
            "documents": 1,
            "credits": 0.9,
            "needs_extra_document": true,
            "extra_document_cost": 1.0,
            "total_credits": 1.9,
            "breakdown": [[
                "code": "NotificationWhatsapp",
                "name": "Whatsapp Notification",
                "cost": 0.9,
                "quantity": 2,
                "unit_cost": 0.45,
            ]],
            "document_balance": 0,
            "credit_balance": 10,
            "has_sufficient_resources": true,
            "blocking_reason": NSNull(),
            "message": "Resources available",
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let estimate = try JSONDecoder.assinafy.decode(CostEstimate.self, from: data)
        XCTAssertEqual(estimate.documents, 1)
        XCTAssertEqual(estimate.totalCredits, 1.9)
        XCTAssertEqual(estimate.breakdown.count, 1)
        XCTAssertEqual(estimate.breakdown.first?.code, "NotificationWhatsapp")
        XCTAssertEqual(estimate.breakdown.first?.quantity, 2)
        XCTAssertEqual(estimate.breakdown.first?.unitCost, 0.45)
        XCTAssertNil(estimate.blockingReason)
        XCTAssertEqual(estimate.message, "Resources available")
    }

    func testCostEstimateRejectsUnrecognizedObject() throws {
        let data = try JSONSerialization.data(withJSONObject: ["unexpected": 1])
        XCTAssertThrowsError(try JSONDecoder.assinafy.decode(CostEstimate.self, from: data))
    }

    // MARK: - Signer

    func testSearchSignerDocumentsUsesSearchPath() async throws {
        let resource = SignerResource(http: mock, defaultAccountId: "acc")
        mock.stubEnvelopeList([])
        _ = try await resource.searchSignerDocuments(signerId: "s1", signerAccessCode: "code", search: "x")
        XCTAssertEqual(mock.lastRequest?.path, "/signers/s1/documents/search")
        let items = mock.lastRequest?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "signer-access-code", value: "code")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "search", value: "x")))
    }

    func testUploadSignatureReuseAddsQueryFlag() async throws {
        let resource = SignerResource(http: mock, defaultAccountId: "acc")
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.uploadSignature(signerAccessCode: "code", type: .signature,
                                           imageData: Data("x".utf8), reuse: true)
        let items = mock.lastRequest?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "reuse", value: "true")))
    }
}
