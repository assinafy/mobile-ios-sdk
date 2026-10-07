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
    ///
    /// Mirrors `POST /login`. Throws ``MFARequiredError`` when the user has
    /// two-factor authentication enabled; finish with ``verifyMFA(_:)``.
    public func login(_ payload: LoginPayload) async throws -> LoginResponse {
        let request = try APIRequest.post("/login", body: payload).withoutWorkspaceCredential()
        return try await call("Failed to login", request: request)
    }

    /// Exchanges a supported social-login token for an Assinafy access token.
    ///
    /// Mirrors `POST /authentication/social-login`. Throws ``MFARequiredError``
    /// when the user has two-factor authentication enabled.
    public func socialLogin(_ payload: SocialLoginPayload) async throws -> LoginResponse {
        let request = try APIRequest.post("/authentication/social-login", body: payload)
            .withoutWorkspaceCredential()
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
            .withoutWorkspaceCredential()
        try await callVoid("Failed to request password reset", request: request)
    }

    /// Requests a password-reset email and returns `{ "email": string }`.
    public func requestPasswordResetAndReturnResponse(
        _ payload: RequestPasswordResetPayload
    ) async throws -> EmailResponse {
        try await call(
            "Failed to request password reset",
            request: try APIRequest.put("/authentication/request-password-reset", body: payload)
                .withoutWorkspaceCredential()
        )
    }

    /// Resets a password using the emailed token.
    public func resetPassword(_ payload: ResetPasswordPayload) async throws {
        let request = try APIRequest.put("/authentication/reset-password", body: payload)
            .withoutWorkspaceCredential()
        try await callVoid("Failed to reset password", request: request)
    }

    /// Resets a password and returns the API's `{ "email": string }` data payload.
    public func resetPasswordAndReturnResponse(
        _ payload: ResetPasswordPayload
    ) async throws -> EmailResponse {
        try await call(
            "Failed to reset password",
            request: try APIRequest.put("/authentication/reset-password", body: payload)
                .withoutWorkspaceCredential()
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

    // MARK: Two-factor authentication

    /// Completes a two-factor login.
    ///
    /// Mirrors `POST /authentication/mfa/verify`. Public route; the token is
    /// single-use and expires five minutes after login.
    public func verifyMFA(_ payload: VerifyMFAPayload) async throws -> LoginResponse {
        try requireNonBlank(payload.mfaToken, name: "MFA token")
        try requireNonBlank(payload.code, name: "Two-factor code")
        let request = try APIRequest.post("/authentication/mfa/verify", body: payload)
            .withoutWorkspaceCredential()
        return try await call("Failed to verify two-factor code", request: request)
    }

    /// Lists the user's two-factor methods and remaining recovery codes.
    ///
    /// Mirrors `GET /users/self/mfa`.
    public func mfaStatus() async throws -> MFAStatus {
        try await call("Failed to fetch two-factor methods", request: .get("/users/self/mfa"))
    }

    /// Starts authenticator enrollment. Two-factor is not active until ``confirmTOTP(_:)``.
    ///
    /// Mirrors `POST /users/self/mfa/totp`.
    public func enrollTOTP(label: String? = nil) async throws -> TOTPEnrollment {
        let request = try APIRequest.post("/users/self/mfa/totp", body: EnrollTOTPBody(label: label))
        return try await call("Failed to start authenticator enrollment", request: request)
    }

    /// Activates an authenticator and returns the recovery codes, shown only once.
    ///
    /// Mirrors `PUT /users/self/mfa/totp/confirm`.
    public func confirmTOTP(_ payload: ConfirmTOTPPayload) async throws -> [String] {
        try requireNonBlank(payload.id, name: "MFA method ID")
        try requireNonBlank(payload.code, name: "Two-factor code")
        let request = try APIRequest.put("/users/self/mfa/totp/confirm", body: payload)
        let result: MFARecoveryCodes = try await call("Failed to confirm authenticator", request: request)
        return result.recoveryCodes
    }

    /// Issues ten new recovery codes and invalidates the previous set.
    ///
    /// Mirrors `POST /users/self/mfa/recovery-codes`.
    public func regenerateRecoveryCodes(_ proof: MFAReauthPayload) async throws -> [String] {
        try requireProof(proof)
        let request = try APIRequest.post("/users/self/mfa/recovery-codes", body: proof)
        let result: MFARecoveryCodes = try await call("Failed to regenerate recovery codes", request: request)
        return result.recoveryCodes
    }

    /// Removes a two-factor method and returns whether two-factor is still enabled.
    /// Removing the last method also discards the recovery codes.
    ///
    /// Mirrors `DELETE /users/self/mfa/{id}`.
    public func removeMFAMethod(id: String, _ proof: MFAReauthPayload) async throws -> Bool {
        let mid = try requireId(id, name: "MFA method ID")
        try requireProof(proof)
        let request = try APIRequest.delete("/users/self/mfa/\(mid)", body: proof)
        let result: MFAEnabledState = try await call("Failed to remove two-factor method", request: request)
        return result.isMfaEnabled
    }

    /// Body values are opaque, so only blankness is checked (path rules do not apply).
    private func requireNonBlank(_ value: String, name: String) throws {
        guard !isBlank(value) else { throw ValidationError("\(name) is required") }
    }

    private func isBlank(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    private func requireProof(_ proof: MFAReauthPayload) throws {
        guard !isBlank(proof.password) || !isBlank(proof.code) else {
            throw ValidationError("Re-authentication requires the password or a two-factor code")
        }
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

    /// Completion form of `socialLogin`; delivers the result on the main queue.
    @objc(socialLoginWithPayload:completion:)
    public func socialLogin(
        _ payload: SocialLoginPayload,
        completion: @escaping (LoginResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.socialLogin(payload) }, completion: completion)
    }

    /// Completion form of `currentUserProfile`; delivers the result on the main queue.
    @objc(currentUserProfileWithCompletion:)
    public func currentUserProfile(
        completion: @escaping (User?, Error?) -> Void
    ) {
        withCompletion({ try await self.currentUserProfile() }, completion: completion)
    }

    /// Completion form of `changePassword`; delivers the result on the main queue.
    @objc(changePasswordWithPayload:completion:)
    public func changePassword(
        _ payload: ChangePasswordPayload,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.changePassword(payload) }, completion: completion)
    }

    /// Completion form of `changePasswordAndReturnResponse`; delivers the result on the main queue.
    @objc(changePasswordAndReturnResponseWithPayload:completion:)
    public func changePasswordAndReturnResponse(
        _ payload: ChangePasswordPayload,
        completion: @escaping (EmailResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.changePasswordAndReturnResponse(payload) }, completion: completion)
    }

    /// Completion form of `requestPasswordReset`; delivers the result on the main queue.
    @objc(requestPasswordResetWithPayload:completion:)
    public func requestPasswordReset(
        _ payload: RequestPasswordResetPayload,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.requestPasswordReset(payload) }, completion: completion)
    }

    /// Completion form of `requestPasswordResetAndReturnResponse`; delivers the result on the main queue.
    @objc(requestPasswordResetAndReturnResponseWithPayload:completion:)
    public func requestPasswordResetAndReturnResponse(
        _ payload: RequestPasswordResetPayload,
        completion: @escaping (EmailResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.requestPasswordResetAndReturnResponse(payload) }, completion: completion)
    }

    /// Completion form of `resetPassword`; delivers the result on the main queue.
    @objc(resetPasswordWithPayload:completion:)
    public func resetPassword(
        _ payload: ResetPasswordPayload,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.resetPassword(payload) }, completion: completion)
    }

    /// Completion form of `resetPasswordAndReturnResponse`; delivers the result on the main queue.
    @objc(resetPasswordAndReturnResponseWithPayload:completion:)
    public func resetPasswordAndReturnResponse(
        _ payload: ResetPasswordPayload,
        completion: @escaping (EmailResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.resetPasswordAndReturnResponse(payload) }, completion: completion)
    }

    /// Completion form of `deleteAPIKey`; delivers the result on the main queue.
    @objc(deleteAPIKeyWithCompletion:)
    public func deleteAPIKey(
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.deleteAPIKey() }, completion: completion)
    }

    /// Completion form of `verifyMFA`; delivers the result on the main queue.
    @objc(verifyMFAWithPayload:completion:)
    public func verifyMFA(
        _ payload: VerifyMFAPayload,
        completion: @escaping (LoginResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.verifyMFA(payload) }, completion: completion)
    }

    /// Completion form of `mfaStatus`; delivers the result on the main queue.
    @objc(mfaStatusWithCompletion:)
    public func mfaStatus(completion: @escaping (MFAStatus?, Error?) -> Void) {
        withCompletion({ try await self.mfaStatus() }, completion: completion)
    }

    /// Completion form of `enrollTOTP`; delivers the result on the main queue.
    @objc(enrollTOTPWithLabel:completion:)
    public func enrollTOTP(
        label: String?,
        completion: @escaping (TOTPEnrollment?, Error?) -> Void
    ) {
        withCompletion({ try await self.enrollTOTP(label: label) }, completion: completion)
    }

    /// Completion form of `confirmTOTP`; delivers the recovery codes on the main queue.
    @objc(confirmTOTPWithPayload:completion:)
    public func confirmTOTP(
        _ payload: ConfirmTOTPPayload,
        completion: @escaping ([String]?, Error?) -> Void
    ) {
        withCompletion({ try await self.confirmTOTP(payload) }, completion: completion)
    }

    /// Completion form of `regenerateRecoveryCodes`; delivers the codes on the main queue.
    @objc(regenerateRecoveryCodesWithProof:completion:)
    public func regenerateRecoveryCodes(
        _ proof: MFAReauthPayload,
        completion: @escaping ([String]?, Error?) -> Void
    ) {
        withCompletion({ try await self.regenerateRecoveryCodes(proof) }, completion: completion)
    }

    /// Completion form of `removeMFAMethod`; delivers whether two-factor is still enabled on the main queue.
    @objc(removeMFAMethodWithId:proof:completion:)
    public func removeMFAMethod(
        id: String,
        _ proof: MFAReauthPayload,
        completion: @escaping (NSNumber?, Error?) -> Void
    ) {
        withCompletion({ NSNumber(value: try await self.removeMFAMethod(id: id, proof)) }, completion: completion)
    }
}
