import Foundation

/// Manages Assinafy authentication and user API-key endpoints.
///
/// Access this resource through ``AssinafyClient/auth``.
///
/// Login and password-reset calls do not require credentials. API-key endpoints
/// require a bearer-token client because they operate on the authenticated user.
@objcMembers
public final class AuthResource: BaseResource {

    // MARK: - Swift async API

    /// Logs in with email and password and returns an access token plus user accounts.
    public func login(_ payload: LoginPayload) async throws -> LoginResponse {
        let request = try APIRequest.post("/login", body: payload)
        return try await call("Failed to login", request: request)
    }

    /// Exchanges a supported social-login token for an Assinafy access token.
    public func socialLogin(_ payload: SocialLoginPayload) async throws -> LoginResponse {
        let request = try APIRequest.post("/authentication/social-login", body: payload)
        return try await call("Failed to complete social login", request: request)
    }

    /// Changes a user's password.
    public func changePassword(_ payload: ChangePasswordPayload) async throws {
        let request = try APIRequest.put("/authentication/change-password", body: payload)
        try await callVoid("Failed to change password", request: request)
    }

    /// Sends a password reset email.
    public func requestPasswordReset(_ payload: RequestPasswordResetPayload) async throws {
        let request = try APIRequest.put("/authentication/request-password-reset", body: payload)
        try await callVoid("Failed to request password reset", request: request)
    }

    /// Resets a password using the emailed token.
    public func resetPassword(_ payload: ResetPasswordPayload) async throws {
        let request = try APIRequest.put("/authentication/reset-password", body: payload)
        try await callVoid("Failed to reset password", request: request)
    }

    /// Retrieves the masked user API key, when one exists.
    public func getAPIKey() async throws -> String? {
        let response: APIKeyResponse = try await call(
            "Failed to fetch API key",
            request: .get("/users/api-keys")
        )
        return response.apiKey
    }

    /// Creates a new user API key. The API replaces any previous key.
    public func createAPIKey(_ payload: CreateAPIKeyPayload) async throws -> String {
        let response: APIKeyResponse = try await call(
            "Failed to create API key",
            request: try APIRequest.post("/users/api-keys", body: payload)
        )
        guard let apiKey = response.apiKey, !apiKey.isEmpty else {
            throw ValidationError("API key response contained no api_key")
        }
        return apiKey
    }

    /// Deletes the current user API key.
    public func deleteAPIKey() async throws {
        try await callVoid("Failed to delete API key", request: .delete("/users/api-keys"))
    }

    // MARK: - Objective-C / completion-handler API

    /// Logs in and delivers the result on the **main queue**.
    @objc(loginWithPayload:completion:)
    public func login(
        _ payload: LoginPayload,
        completion: @escaping (LoginResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.login(payload) }, completion: completion)
    }

    /// Retrieves the masked API key and delivers the result on the **main queue**.
    @objc(getAPIKeyWithCompletion:)
    public func getAPIKey(completion: @escaping (NSString?, Error?) -> Void) {
        withOptionalCompletion({ (try await self.getAPIKey()) as NSString? }, completion: completion)
    }

    /// Creates an API key and delivers the result on the **main queue**.
    @objc(createAPIKeyWithPayload:completion:)
    public func createAPIKey(
        _ payload: CreateAPIKeyPayload,
        completion: @escaping (NSString?, Error?) -> Void
    ) {
        withCompletion({ (try await self.createAPIKey(payload)) as NSString }, completion: completion)
    }
}
