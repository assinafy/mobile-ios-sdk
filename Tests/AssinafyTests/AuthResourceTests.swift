import XCTest
@testable import Assinafy

final class AuthResourceTests: XCTestCase {
    var mock: MockHTTPClient!
    var resource: AuthResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        resource = AuthResource(http: mock)
    }

    private func loginResponseDict() -> [String: Any] {
        [
            "access_token": "access-token",
            "user": [
                "id": "user-1",
                "name": "Test User",
                "email": "test@example.invalid",
                "is_email_verified": true,
                "has_accepted_terms": true,
                "created_at": "2024-01-01T00:00:00Z",
            ],
            "accounts": [
                [
                    "id": "account-1",
                    "name": "Test Account",
                    "roles": ["owner"],
                    "is_delete_allowed": true,
                    "created_at": "2024-01-01T00:00:00Z",
                ],
            ],
        ]
    }

    private func notificationPreferencesDict() -> [String: Any] {
        [
            "DocumentCompleted": true,
            "SignerDeclined": false,
            "DocumentCancelled": true,
            "DocumentAboutToExpire": false,
            "DocumentExpired": true,
            "DocumentExpirationReset": false,
            "DocumentProcessingFailed": true,
            "TemplateProcessingFailed": false,
            "SignerWhatsappFailed": true,
        ]
    }

    func testLoginUsesDocumentedEndpoint() async throws {
        mock.stubEnvelope(loginResponseDict())

        let result = try await resource.login(LoginPayload(email: "test@example.invalid", password: "password"))

        XCTAssertEqual(result.accessToken, "access-token")
        XCTAssertEqual(result.user.email, "test@example.invalid")
        XCTAssertEqual(result.accounts.first?.id, "account-1")
        XCTAssertEqual(mock.lastRequest?.path, "/login")
        XCTAssertEqual(mock.lastRequest?.method, .post)
    }

    func testSocialLoginUsesDocumentedEndpoint() async throws {
        mock.stubEnvelope(loginResponseDict())

        _ = try await resource.socialLogin(SocialLoginPayload(token: "google-token", hasAcceptedTerms: true))

        XCTAssertEqual(mock.lastRequest?.path, "/authentication/social-login")
        XCTAssertEqual(mock.lastRequest?.method, .post)
    }

    func testCurrentUserDecodesDocumentedDirectUser() async throws {
        mock.stubEnvelope([
            "id": "user-1",
            "name": "Test User",
            "email": "test@example.invalid",
            "created_at": "2026-01-01T00:00:00Z",
        ])

        let result = try await resource.currentUser()

        XCTAssertEqual(result.user.id, "user-1")
        XCTAssertTrue(result.accounts.isEmpty)
        XCTAssertEqual(mock.lastRequest?.path, "/users/self")
    }

    func testCurrentUserStillDecodesLegacyWrapper() async throws {
        mock.stubEnvelope([
            "user": [
                "id": "user-1",
                "name": "Test User",
                "email": "test@example.invalid",
                "created_at": "2026-01-01T00:00:00Z",
            ],
            "accounts": [[
                "id": "account-1",
                "name": "Test Account",
                "created_at": "2026-01-01T00:00:00Z",
            ]],
        ])

        let result = try await resource.currentUser()

        XCTAssertEqual(result.user.id, "user-1")
        XCTAssertEqual(result.accounts.first?.id, "account-1")
    }

    func testCurrentUserProfileAcceptsCompatibilityWrapper() async throws {
        mock.stubEnvelope([
            "user": [
                "id": "user-1",
                "name": "Test User",
                "email": "test@example.invalid",
                "created_at": "2026-01-01T00:00:00Z",
            ],
            "accounts": [],
        ])

        let user = try await resource.currentUserProfile()

        XCTAssertEqual(user.id, "user-1")
    }

    func testGetNotificationPreferencesDecodesAllDocumentedFields() async throws {
        mock.stubEnvelope(notificationPreferencesDict())

        let result = try await resource.getNotificationPreferences()

        XCTAssertTrue(result.documentCompleted)
        XCTAssertFalse(result.signerDeclined)
        XCTAssertTrue(result.documentCancelled)
        XCTAssertFalse(result.documentAboutToExpire)
        XCTAssertTrue(result.documentExpired)
        XCTAssertFalse(result.documentExpirationReset)
        XCTAssertTrue(result.documentProcessingFailed)
        XCTAssertFalse(result.templateProcessingFailed)
        XCTAssertTrue(result.signerWhatsappFailed)
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/users/self/notification-preferences")
    }

    func testUpdateNotificationPreferencesSendsOnlySelectedFields() async throws {
        mock.stubEnvelope(notificationPreferencesDict())

        _ = try await resource.updateNotificationPreferences(
            UpdateNotificationPreferencesPayload(
                documentCompleted: false,
                signerWhatsappFailed: true
            )
        )

        let data = try XCTUnwrap(mock.lastRequest?.body)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body.count, 2)
        XCTAssertEqual(body["DocumentCompleted"] as? Bool, false)
        XCTAssertEqual(body["SignerWhatsappFailed"] as? Bool, true)
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/users/self/notification-preferences")
    }

    func testUpdateNotificationPreferencesRejectsEmptyPayload() async {
        await assertThrowsValidationError {
            _ = try await self.resource.updateNotificationPreferences(
                UpdateNotificationPreferencesPayload()
            )
        }
        XCTAssertNil(mock.lastRequest)
    }

    func testChangePasswordUsesPut() async throws {
        mock.stubEnvelope(["email": "test@example.invalid"])

        try await resource.changePassword(
            ChangePasswordPayload(email: "test@example.invalid", password: "old", newPassword: "new")
        )

        XCTAssertEqual(mock.lastRequest?.path, "/authentication/change-password")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testRequestPasswordResetUsesPut() async throws {
        mock.stubEnvelope(["email": "test@example.invalid"])

        try await resource.requestPasswordReset(RequestPasswordResetPayload(email: "test@example.invalid"))

        XCTAssertEqual(mock.lastRequest?.path, "/authentication/request-password-reset")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testResetPasswordUsesPut() async throws {
        mock.stubEnvelope(["email": "test@example.invalid"])

        try await resource.resetPassword(
            ResetPasswordPayload(email: "test@example.invalid", token: "reset-token", newPassword: "new")
        )

        XCTAssertEqual(mock.lastRequest?.path, "/authentication/reset-password")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testGetAPIKeyReturnsMaskedKey() async throws {
        mock.stubEnvelope(["api_key": "********abc"])

        let key = try await resource.getAPIKey()

        XCTAssertEqual(key, "********abc")
        XCTAssertEqual(mock.lastRequest?.path, "/users/api-keys")
        XCTAssertEqual(mock.lastRequest?.method, .get)
    }

    func testCreateAPIKeyReturnsNewKey() async throws {
        mock.stubEnvelope(["api_key": "new-key"])

        let key = try await resource.createAPIKey(CreateAPIKeyPayload(password: "password"))

        XCTAssertEqual(key, "new-key")
        XCTAssertEqual(mock.lastRequest?.path, "/users/api-keys")
        XCTAssertEqual(mock.lastRequest?.method, .post)
    }

    func testDeleteAPIKeyUsesDocumentedEndpoint() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 204))

        try await resource.deleteAPIKey()

        XCTAssertEqual(mock.lastRequest?.path, "/users/api-keys")
        XCTAssertEqual(mock.lastRequest?.method, .delete)
    }
}

final class MFATests: XCTestCase {
    private var mock: MockHTTPClient!
    private var auth: AuthResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        auth = AuthResource(http: mock)
    }

    private func body() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(mock.lastRequest?.body)) as? [String: Any])
    }

    func testLoginWithChallengeThrowsMFARequired() async {
        mock.stubEnvelope(["mfa_token": "challenge-1"])
        do {
            _ = try await auth.login(LoginPayload(email: "user@example.invalid", password: "pw"))
            XCTFail("Expected MFARequiredError")
        } catch let error as MFARequiredError {
            XCTAssertEqual(error.mfaToken, "challenge-1")
            XCTAssertEqual((error as NSError).domain, ASFErrorDomain.mfaRequired)
            XCTAssertEqual((error as NSError).userInfo["mfaToken"] as? String, "challenge-1")
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testVerifyMFAIsPublicAndSendsDocumentedBody() async throws {
        mock.stubEnvelope([
            "access_token": "jwt",
            "user": ["id": "u1", "name": "N", "email": "user@example.invalid", "created_at": "2026-01-01T00:00:00Z"],
            "accounts": [],
        ])
        let session = try await auth.verifyMFA(VerifyMFAPayload(mfaToken: "challenge/1+a==", code: "123456"))
        XCTAssertEqual(session.accessToken, "jwt")
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/authentication/mfa/verify")
        XCTAssertEqual(mock.lastRequest?.credential, .withheld)
        let json = try body()
        XCTAssertEqual(json["mfa_token"] as? String, "challenge/1+a==")
        XCTAssertEqual(json["code"] as? String, "123456")
    }

    func testMFAStatusDecodes() async throws {
        mock.stubEnvelope([
            "methods": [["id": "m1", "type": "Totp", "label": "My phone",
                         "confirmed_at": "2026-09-09T14:21:03Z", "last_used_at": "2026-09-09T18:02:44Z"]],
            "recovery_codes_remaining": 8,
        ])
        let status = try await auth.mfaStatus()
        XCTAssertEqual(mock.lastRequest?.path, "/users/self/mfa")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        XCTAssertEqual(status.methods.first?.type, "Totp")
        XCTAssertEqual(status.methods.first?.label, "My phone")
        XCTAssertEqual(status.recoveryCodesRemaining, 8)
    }

    func testEnrollAndConfirmTOTP() async throws {
        mock.stubEnvelope(["id": "m1", "secret": "GEZDGNBV", "provisioning_uri": "otpauth://totp/x?secret=GEZDGNBV"])
        let enrollment = try await auth.enrollTOTP(label: "My phone")
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/users/self/mfa/totp")
        XCTAssertEqual(try body()["label"] as? String, "My phone")
        XCTAssertEqual(enrollment.provisioningURI, "otpauth://totp/x?secret=GEZDGNBV")

        mock.stubEnvelope(["recovery_codes": ["AAAA-BBBB-CCCC"]])
        let codes = try await auth.confirmTOTP(ConfirmTOTPPayload(id: "m1", code: "123456", reauthCode: "654321"))
        XCTAssertEqual(codes, ["AAAA-BBBB-CCCC"])
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/users/self/mfa/totp/confirm")
        let json = try body()
        XCTAssertEqual(json["reauth_code"] as? String, "654321")
        XCTAssertNil(json["password"])
    }

    func testVerifyMFARejectsBlankCodeBeforeSending() async {
        do {
            _ = try await auth.verifyMFA(VerifyMFAPayload(mfaToken: "t", code: " "))
            XCTFail("Expected ValidationError")
        } catch {
            XCTAssertTrue(error is ValidationError)
        }
        XCTAssertNil(mock.lastRequest)
    }

    func testRecoveryCodesAndRemovalRequireProof() async throws {
        do {
            _ = try await auth.regenerateRecoveryCodes(MFAReauthPayload())
            XCTFail("Expected ValidationError")
        } catch {
            XCTAssertTrue(error is ValidationError)
        }
        XCTAssertNil(mock.lastRequest)

        mock.stubEnvelope(["recovery_codes": ["A", "B"]])
        let codes = try await auth.regenerateRecoveryCodes(MFAReauthPayload(password: "pw"))
        XCTAssertEqual(codes, ["A", "B"])
        XCTAssertEqual(mock.lastRequest?.path, "/users/self/mfa/recovery-codes")

        mock.stubEnvelope(["is_mfa_enabled": false])
        let enabled = try await auth.removeMFAMethod(id: "m1", MFAReauthPayload(code: "123456"))
        XCTAssertFalse(enabled)
        XCTAssertEqual(mock.lastRequest?.method, .delete)
        XCTAssertEqual(mock.lastRequest?.path, "/users/self/mfa/m1")
        XCTAssertEqual(try body()["code"] as? String, "123456")
    }
}
