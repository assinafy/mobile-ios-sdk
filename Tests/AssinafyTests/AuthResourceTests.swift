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
                "email": "test@example.com",
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

        let result = try await resource.login(LoginPayload(email: "test@example.com", password: "password"))

        XCTAssertEqual(result.accessToken, "access-token")
        XCTAssertEqual(result.user.email, "test@example.com")
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
            "email": "test@example.com",
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
                "email": "test@example.com",
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
                "email": "test@example.com",
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
        mock.stubEnvelope(["email": "test@example.com"])

        try await resource.changePassword(
            ChangePasswordPayload(email: "test@example.com", password: "old", newPassword: "new")
        )

        XCTAssertEqual(mock.lastRequest?.path, "/authentication/change-password")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testRequestPasswordResetUsesPut() async throws {
        mock.stubEnvelope(["email": "test@example.com"])

        try await resource.requestPasswordReset(RequestPasswordResetPayload(email: "test@example.com"))

        XCTAssertEqual(mock.lastRequest?.path, "/authentication/request-password-reset")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testResetPasswordUsesPut() async throws {
        mock.stubEnvelope(["email": "test@example.com"])

        try await resource.resetPassword(
            ResetPasswordPayload(email: "test@example.com", token: "reset-token", newPassword: "new")
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
