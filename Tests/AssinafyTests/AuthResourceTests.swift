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
