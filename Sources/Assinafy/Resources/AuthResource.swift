import Foundation

/// Manages Assinafy authentication and user API-key endpoints.
///
/// Access this resource through ``AssinafyClient/auth``.
///
/// Login and password-reset calls do not require credentials. API-key endpoints
/// require a bearer-token client because they operate on the authenticated user.
@objcMembers
public final class AuthResource: BaseResource, @unchecked Sendable {

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

    /// Links a social-login provider token to the authenticated user's account.
    ///
    /// Mirrors `POST /auth/link-social-login`.
    public func linkSocialLogin(_ payload: LinkSocialLoginPayload) async throws {
        let request = try APIRequest.post("/auth/link-social-login", body: payload)
        try await callVoid("Failed to link social login", request: request)
    }

    /// Fetches the authenticated user's profile.
    ///
    /// Mirrors `GET /users/self`.
    public func currentUser() async throws -> SelfResponse {
        return try await call("Failed to fetch current user", request: .get("/users/self"))
    }

    /// Fetches the user documented for `GET /users/self`.
    ///
    /// Both direct `data: User` and compatibility `{ user, accounts }` payloads
    /// are accepted.
    public func currentUserProfile() async throws -> User {
        let response: SelfResponse = try await call(
            "Failed to fetch current user",
            request: .get("/users/self")
        )
        return response.user
    }

    /// Fetches all owner-notification preferences for the authenticated user.
    ///
    /// Mirrors `GET /users/self/notification-preferences`.
    public func getNotificationPreferences() async throws -> NotificationPreferences {
        try await call(
            "Failed to fetch notification preferences",
            request: .get("/users/self/notification-preferences")
        )
    }

    /// Updates selected owner-notification preferences and returns the full map.
    ///
    /// Mirrors `PUT /users/self/notification-preferences`. At least one field
    /// must be supplied; omitted fields retain their current server value.
    public func updateNotificationPreferences(
        _ payload: UpdateNotificationPreferencesPayload
    ) async throws -> NotificationPreferences {
        guard !payload.isEmpty else {
            throw ValidationError("At least one notification preference is required")
        }
        return try await call(
            "Failed to update notification preferences",
            request: try APIRequest.put("/users/self/notification-preferences", body: payload)
        )
    }

    /// Fetches the authenticated user's document-funnel KPIs, summed across all
    /// accounts they belong to.
    ///
    /// - Note: The sandbox host currently returns `404` for this endpoint.
    ///
    /// Mirrors `GET /users/self/stats`.
    ///
    /// - Parameter params: Granularity (`monthly`/`daily`) and month filter.
    /// - Returns: A zero-filled series of ``DocumentStatsRow`` values, most recent first.
    public func stats(params: AccountStatsParams = AccountStatsParams()) async throws -> [DocumentStatsRow] {
        let items = params.toQueryItems()
        let result: PaginatedResult<DocumentStatsRow> = try await callList(
            "Failed to fetch user stats",
            request: .get("/users/self/stats", queryItems: items.isEmpty ? nil : items)
        )
        return result.data
    }

    /// Changes a user's password.
    public func changePassword(_ payload: ChangePasswordPayload) async throws {
        let request = try APIRequest.put("/authentication/change-password", body: payload)
        try await callVoid("Failed to change password", request: request)
    }

    /// Changes a password and returns the API's `{ "email": string }` data payload.
    public func changePasswordAndReturnResponse(
        _ payload: ChangePasswordPayload
    ) async throws -> EmailResponse {
        try await call(
            "Failed to change password",
            request: try APIRequest.put("/authentication/change-password", body: payload)
        )
    }

    /// Sends a password reset email.
    public func requestPasswordReset(_ payload: RequestPasswordResetPayload) async throws {
        let request = try APIRequest.put("/authentication/request-password-reset", body: payload)
        try await callVoid("Failed to request password reset", request: request)
    }

    /// Requests a password-reset email and returns `{ "email": string }`.
    public func requestPasswordResetAndReturnResponse(
        _ payload: RequestPasswordResetPayload
    ) async throws -> EmailResponse {
        try await call(
            "Failed to request password reset",
            request: try APIRequest.put("/authentication/request-password-reset", body: payload)
        )
    }

    /// Resets a password using the emailed token.
    public func resetPassword(_ payload: ResetPasswordPayload) async throws {
        let request = try APIRequest.put("/authentication/reset-password", body: payload)
        try await callVoid("Failed to reset password", request: request)
    }

    /// Resets a password and returns the API's `{ "email": string }` data payload.
    public func resetPasswordAndReturnResponse(
        _ payload: ResetPasswordPayload
    ) async throws -> EmailResponse {
        try await call(
            "Failed to reset password",
            request: try APIRequest.put("/authentication/reset-password", body: payload)
        )
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
            throw AssinafySDKError("API key response contained no api_key")
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

    /// Fetches the authenticated user and delivers the result on the **main queue**.
    @objc(currentUserWithCompletion:)
    public func currentUser(completion: @escaping (SelfResponse?, Error?) -> Void) {
        withCompletion({ try await self.currentUser() }, completion: completion)
    }

    /// Fetches notification preferences and delivers them on the **main queue**.
    @objc(getNotificationPreferencesWithCompletion:)
    public func getNotificationPreferences(
        completion: @escaping (NotificationPreferences?, Error?) -> Void
    ) {
        withCompletion({ try await self.getNotificationPreferences() }, completion: completion)
    }

    /// Updates notification preferences and delivers the full map on the **main queue**.
    @objc(updateNotificationPreferences:completion:)
    public func updateNotificationPreferences(
        _ payload: UpdateNotificationPreferencesPayload,
        completion: @escaping (NotificationPreferences?, Error?) -> Void
    ) {
        withCompletion({ try await self.updateNotificationPreferences(payload) }, completion: completion)
    }

    /// Fetches the user's KPIs and delivers the result on the **main queue**.
    @objc(statsWithParams:completion:)
    public func stats(
        params: AccountStatsParams,
        completion: @escaping ([DocumentStatsRow]?, Error?) -> Void
    ) {
        withCompletion({ try await self.stats(params: params) }, completion: completion)
    }

    /// Links a social login and notifies the **main queue** upon completion.
    @objc(linkSocialLogin:completion:)
    public func linkSocialLogin(
        _ payload: LinkSocialLoginPayload,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.linkSocialLogin(payload) }, completion: completion)
    }
}
