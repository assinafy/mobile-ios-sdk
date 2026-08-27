import XCTest
@testable import Assinafy

/// Contract tests that pin HTTP methods, paths, payloads, and response decoding.
final class ContractEndpointTests: XCTestCase {
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

    func testCurrentUserProfileDecodesDirectUserPayload() async throws {
        let resource = AuthResource(http: mock)
        mock.stubEnvelope([
            "id": "u1", "name": "SDK User", "email": "user@example.invalid",
            "created_at": "2026-01-01", "is_password_set": true,
        ])

        let user = try await resource.currentUserProfile()

        XCTAssertEqual(user.id, "u1")
        XCTAssertEqual(mock.lastRequest?.path, "/users/self")
    }

    func testPasswordOperationsExposeEmailResponsePayloads() async throws {
        let resource = AuthResource(http: mock)
        mock.stubEnvelope(["email": "user@example.invalid"])
        mock.stubEnvelope(["email": "user@example.invalid"])
        mock.stubEnvelope(["email": "user@example.invalid"])

        let changed = try await resource.changePasswordAndReturnResponse(
            ChangePasswordPayload(
                email: "user@example.invalid",
                password: "old-secret",
                newPassword: "new-secret"
            )
        )
        let requested = try await resource.requestPasswordResetAndReturnResponse(
            RequestPasswordResetPayload(email: "user@example.invalid")
        )
        let reset = try await resource.resetPasswordAndReturnResponse(
            ResetPasswordPayload(
                email: "user@example.invalid",
                token: "reset-token",
                newPassword: "new-secret"
            )
        )

        XCTAssertEqual(changed.email, "user@example.invalid")
        XCTAssertEqual(requested.email, "user@example.invalid")
        XCTAssertEqual(reset.email, "user@example.invalid")
        XCTAssertEqual(mock.allRequests.map(\.path), [
            "/authentication/change-password",
            "/authentication/request-password-reset",
            "/authentication/reset-password",
        ])
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

    func testWorkspaceStatsRejectsMalformedKnownFields() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "period": "2026-06",
            "documents_uploaded": "three",
        ])

        XCTAssertThrowsError(try JSONDecoder.assinafy.decode(DocumentStatsRow.self, from: data))
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
        XCTAssertEqual(estimate.documentCount, 1)
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

    func testCostEstimateRejectsNonFiniteOrFractionalCounts() throws {
        for value: Any in ["NaN", 1.5, "inf"] {
            let data = try JSONSerialization.data(withJSONObject: [
                "documents": 1,
                "breakdown": [["quantity": value]],
            ])
            XCTAssertThrowsError(try JSONDecoder.assinafy.decode(CostEstimate.self, from: data))
        }
    }

    func testCostEstimatePreservesExplicitZeroEstimate() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "documents": 0,
            "estimated_cost": 0,
            "total_credits": 3,
        ])
        let estimate = try JSONDecoder.assinafy.decode(CostEstimate.self, from: data)
        XCTAssertEqual(estimate.estimatedCost, 0)
    }

    // MARK: - Flexible JSON fields

    func testJSONValuePreservesIntegerPrecisionAndRoundTrips() throws {
        let data = Data(
            #"{"signed":9223372036854775807,"unsigned":18446744073709551615,"fraction":1.25}"#.utf8
        )
        let value = try JSONDecoder.assinafy.decode(JSONValue.self, from: data)
        guard case .object(let object) = value.storage else {
            return XCTFail("Expected object")
        }
        XCTAssertEqual(object["signed"], JSONValue(.integer(Int64.max)))
        XCTAssertEqual(object["unsigned"], JSONValue(.unsignedInteger(UInt64.max)))
        XCTAssertEqual(object["fraction"], JSONValue(.number(1.25)))
        XCTAssertEqual(
            try JSONDecoder.assinafy.decode(
                JSONValue.self,
                from: JSONEncoder.assinafy.encode(value)
            ),
            value
        )
    }

    func testDynamicResponseFieldsPreserveJSONAndCompatibilityStrings() throws {
        let activityJSON = #"{"id":1,"event":"updated","message":"ok","origin":{"type":"user"},"payload":[true,2],"created_at":"2026-01-01"}"#
        let activity = try JSONDecoder.assinafy.decode(
            DocumentActivity.self,
            from: Data(activityJSON.utf8)
        )
        guard case .object(let origin)? = activity.originJSON?.storage,
              case .array(let payload)? = activity.payloadJSON?.storage else {
            return XCTFail("Expected activity JSON values")
        }
        XCTAssertEqual(origin["type"], JSONValue(.string("user")))
        XCTAssertEqual(payload, [JSONValue(.bool(true)), JSONValue(.integer(2))])
        XCTAssertTrue(activity.origin.contains("user"))

        let itemJSON = #"{"id":"item-1","value":{"approved":true},"completed":true}"#
        let item = try JSONDecoder.assinafy.decode(AssignmentItem.self, from: Data(itemJSON.utf8))
        guard case .object(let captured)? = item.valueJSON?.storage else {
            return XCTFail("Expected assignment value object")
        }
        XCTAssertEqual(captured["approved"], JSONValue(.bool(true)))
        XCTAssertTrue(item.value?.contains("approved") == true)

        let placementJSON = #"{"id":"p1","field_id":"f1","role_id":"r1","display_settings":null}"#
        let placement = try JSONDecoder.assinafy.decode(
            TemplateFieldPlacement.self,
            from: Data(placementJSON.utf8)
        )
        XCTAssertEqual(placement.displaySettingsJSON, JSONValue(.null))
        XCTAssertEqual(placement.displaySettings, "")
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
                                           imageData: Data([0x89, 0x50, 0x4E, 0x47,
                                                            0x0D, 0x0A, 0x1A, 0x0A]),
                                           reuse: true)
        let items = mock.lastRequest?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "reuse", value: "true")))
    }
}
