import Foundation

/// Drives the OAuth 2.1 authorization code flow with PKCE.
///
/// Access this resource through ``AssinafyClient/oauth``.
///
/// Use OAuth when an application acts **in a user's workspace, with that
/// user's permission** — the user approves a named set of scopes on Assinafy's
/// consent screen, and the resulting token is bound to one workspace and
/// limited to what they approved. Use ``AuthResource`` and an API key or
/// bearer token instead when the code *is* the workspace owner.
///
/// An OAuth token can never reach billing, account lifecycle, credential
/// management, or admin surfaces, whatever scopes it carries.
///
/// ## The flow
/// ```swift
/// // 1. Discover the authorization server (or use the compiled-in defaults).
/// let resource = try await client.oauth.protectedResourceMetadata()
/// let server = try await client.oauth.authorizationServerMetadata(
///     issuer: resource.authorizationServers[0]
/// )
///
/// // 2. Build the authorization URL. Keep `request` until the code is exchanged.
/// let request = OAuthAuthorizationRequest(
///     clientId: clientId,
///     redirectURI: "https://app.example.invalid/oauth/callback",
///     scopes: [.documentsRead, .documentsWrite, .offlineAccess],
///     resource: resource.resource
/// )
/// let url = request.authorizationURL(endpoint: server.authorizationEndpoint)!
///
/// // 3. Open `url` in ASWebAuthenticationSession, receive the callback, verify it.
/// let code = try OAuthCallback(callbackURL: callbackURL)!
///     .validate(against: request, issuer: server.issuer)
///
/// // 4. Exchange the code for a token.
/// let token = try await client.oauth.exchangeAuthorizationCode(
///     .authorizationCode(
///         code: code,
///         redirectURI: request.redirectURI,
///         codeVerifier: request.pkce.codeVerifier,
///         clientId: clientId,
///         resource: resource.resource
///     )
/// )
///
/// // 5. Call the API as the user.
/// let userClient = AssinafyClient(token: token.accessToken)
/// ```
///
/// - Important: A mobile app is a **public client**. It authenticates with
///   PKCE and is never issued a client secret; a secret shipped in an app
///   bundle can be extracted from it. Leave every `clientSecret` `nil`.
@objcMembers
public final class OAuthResource: BaseResource, @unchecked Sendable {

    /// The authorization endpoint published for production, used when an app
    /// skips discovery. Prefer
    /// ``OAuthAuthorizationServerMetadata/authorizationEndpoint``.
    public static let defaultAuthorizationEndpoint = "https://auth.assinafy.com.br/oauth/authorize"

    /// The production authorization server issuer, used when an app skips discovery.
    public static let defaultIssuer = "https://auth.assinafy.com.br"

    /// The API base URL this resource derives host-root discovery paths from,
    /// so sandbox and self-hosted deployments discover their own metadata.
    private let apiBaseURL: URL

    init(
        http: HTTPClientProtocol,
        apiBaseURL: URL,
        logger: Logger = NoopLogger()
    ) {
        self.apiBaseURL = apiBaseURL
        super.init(http: http, defaultAccountId: nil, logger: logger)
    }

    // MARK: - Discovery

    /// Fetches this API's RFC 9728 protected-resource metadata.
    ///
    /// Mirrors `GET /.well-known/oauth-protected-resource`, which lives at the
    /// **host root**, outside the `/v1` base path, and answers with the bare
    /// metadata object rather than the API's usual envelope. Public route: the
    /// request carries no workspace credential.
    ///
    /// - Returns: The resource identifier, its authorization servers, and the
    ///   scopes it accepts.
    public func protectedResourceMetadata() async throws -> OAuthProtectedResourceMetadata {
        let request = APIRequest
            .get(try hostRootURL("/.well-known/oauth-protected-resource"))
            .withoutWorkspaceCredential()
        return try await call("Failed to fetch protected resource metadata", request: request)
    }

    /// Fetches an authorization server's RFC 8414 metadata.
    ///
    /// Mirrors `GET {issuer}/.well-known/oauth-authorization-server` on the
    /// authorization server's own host — a different origin from the API, so
    /// the workspace credential is withheld regardless of client configuration.
    ///
    /// - Parameter issuer: An issuer from
    ///   ``OAuthProtectedResourceMetadata/authorizationServers``. Defaults to
    ///   ``defaultIssuer``.
    /// - Returns: The server's endpoints and supported parameters.
    public func authorizationServerMetadata(
        issuer: String = OAuthResource.defaultIssuer
    ) async throws -> OAuthAuthorizationServerMetadata {
        guard let base = AssinafyClientConfiguration.normalisedBaseURL(issuer) else {
            throw ValidationError("OAuth issuer must be an absolute HTTPS URL")
        }
        let request = APIRequest
            .get(base.absoluteString + "/.well-known/oauth-authorization-server")
            .withoutWorkspaceCredential()
        return try await call("Failed to fetch authorization server metadata", request: request)
    }

    // MARK: - Authorization

    /// Builds the browser URL that starts the flow, using ``defaultAuthorizationEndpoint``.
    ///
    /// Equivalent to
    /// ``OAuthAuthorizationRequest/authorizationURL(endpoint:)`` with the
    /// production endpoint. Prefer the discovered endpoint when the app has
    /// already called ``authorizationServerMetadata(issuer:)``.
    ///
    /// - Parameter request: The authorization request; retain it until the code
    ///   is exchanged, since it holds the PKCE verifier and the `state`.
    /// - Returns: The URL to open, or `nil` when a required value is blank.
    @objc public func authorizationURL(for request: OAuthAuthorizationRequest) -> URL? {
        request.authorizationURL(endpoint: Self.defaultAuthorizationEndpoint)
    }

    // MARK: - Token

    /// Exchanges an authorization code for an access token.
    ///
    /// Mirrors `POST /oauth/token` with `grant_type=authorization_code`. Public
    /// route: the request carries no workspace credential, and the response is
    /// a flat RFC 6749 §5.1 object rather than the API envelope.
    ///
    /// The code is single-use and expires 60 seconds after the user approves:
    /// exchange it at once. The SDK sends the request once, follows no
    /// redirect, and never retries it; after a failure, start a new
    /// authorization.
    ///
    /// - Parameter payload: Build it with
    ///   ``OAuthTokenPayload/authorizationCode(code:redirectURI:codeVerifier:clientId:clientSecret:resource:)``.
    /// - Returns: The access token, its lifetime and granted scopes, plus a
    ///   refresh token when `offline_access` was granted.
    /// - Throws: ``ValidationError`` when the payload is incomplete, or
    ///   ``APIError`` whose ``APIError/oauthError`` names the RFC 6749 failure —
    ///   `invalid_grant` for a bad, expired, replayed, or wrong-client code, a
    ///   `code_verifier` outside the 43–128 character grammar, or a
    ///   `redirect_uri` mismatch; `invalid_client` for a rejected client;
    ///   `invalid_target` for a `resource` this server does not serve.
    public func exchangeAuthorizationCode(
        _ payload: OAuthTokenPayload
    ) async throws -> OAuthTokenResponse {
        try await token(payload, label: "Failed to exchange authorization code")
    }

    /// Exchanges a refresh token for a new access token.
    ///
    /// Mirrors `POST /oauth/token` with `grant_type=refresh_token`. A refresh
    /// token exists only when ``OAuthScope/offlineAccess`` was granted; without
    /// one, send the user through the authorization flow again.
    ///
    /// Every refresh returns a **new** refresh token, valid for a fresh 30 days,
    /// and retires the one sent. Sending a retired refresh token again ends the
    /// whole connection: every token stops working and the user must connect
    /// again. So:
    ///
    /// 1. Persist the returned ``OAuthTokenResponse/refreshToken`` before doing
    ///    anything else with the response.
    /// 2. Treat a failure without an OAuth error — a timeout, a lost connection,
    ///    a cancellation, a `3xx` or `5xx`, a response without a new refresh
    ///    token — as "maybe it worked": the server may have retired the token
    ///    sent. Re-read the stored refresh token and continue only if a
    ///    *different* one was saved since; if it is still the one sent, never
    ///    send it again — ask the user to connect again. Only a ``NetworkError``
    ///    whose `URLError` shows the request never left — `.cannotFindHost`,
    ///    `.dnsLookupFailed`, `.cannotConnectToHost`, `.secureConnectionFailed`,
    ///    or a `.serverCertificate…` code — is safe to retry with the same token.
    /// 3. Refresh one at a time per connection.
    ///
    /// The SDK sends the request once, follows no redirect, and never retries
    /// it. A connection expires only after 30 days without a refresh.
    ///
    /// - Parameter payload: Build it with
    ///   ``OAuthTokenPayload/refreshToken(_:clientId:clientSecret:resource:)``.
    /// - Returns: A fresh access token and the refresh token that replaces the
    ///   one sent.
    /// - Throws: ``APIError`` with `invalid_grant` when the refresh token was
    ///   already used, expired, or revoked, or the user approved the app again
    ///   with different permissions: the connection is over, so ask the user to
    ///   connect again rather than retrying. ``AssinafySDKError`` when a
    ///   successful response carries no new refresh token, which is as
    ///   uncertain as a timeout.
    public func refreshAccessToken(
        _ payload: OAuthTokenPayload
    ) async throws -> OAuthTokenResponse {
        let renewed = try await token(payload, label: "Failed to refresh access token")
        // The sent token is retired now; a response without its replacement
        // leaves the caller nothing it may send next.
        guard let replacement = renewed.refreshToken, !replacement.isBlank,
              replacement != payload.refreshToken else {
            throw AssinafySDKError("Failed to refresh access token: the response carried no new refresh token")
        }
        return renewed
    }

    private func token(_ payload: OAuthTokenPayload, label: String) async throws -> OAuthTokenResponse {
        try payload.validate()
        return try await call(label, request: formPost("/oauth/token", payload))
    }

    /// Revokes an access or refresh token.
    ///
    /// Mirrors `POST /oauth/revoke`. Call it when the user disconnects, then
    /// delete the stored tokens, so the connection ends immediately rather
    /// than at expiry. Revoke the refresh token saved last when there is one:
    /// it is what keeps the connection alive, and every earlier one is already
    /// retired.
    ///
    /// Every token outcome answers `200` — including a token that never
    /// existed, was already revoked, or is malformed — so the endpoint cannot
    /// be used to probe whether a token exists. Only failed client
    /// authentication answers `401 invalid_client`.
    ///
    /// - Parameter payload: The token and the client that owns it.
    public func revoke(_ payload: OAuthRevokePayload) async throws {
        guard !payload.token.isBlank else { throw ValidationError("OAuth token is required") }
        guard !payload.clientId.isBlank else { throw ValidationError("OAuth client ID is required") }
        try await callVoid("Failed to revoke token", request: formPost("/oauth/revoke", payload))
    }

    // MARK: - Claims

    /// Reads OpenID Connect claims about the user who authorized the token.
    ///
    /// Mirrors `GET /oauth/userinfo`, which answers a flat claims object rather
    /// than the API envelope. Call it on a client configured with the OAuth
    /// access token: `AssinafyClient(token: token.accessToken)`.
    ///
    /// - Returns: `sub` always; `name` with ``OAuthScope/profile``, and `email`
    ///   plus `email_verified` with ``OAuthScope/email``.
    /// - Throws: ``APIError`` with `403` when the token lacks
    ///   ``OAuthScope/openID``; ``APIError/insufficientScope`` names the
    ///   missing scope.
    public func userInfo() async throws -> OAuthUserInfo {
        try await call("Failed to fetch userinfo", request: .get("/oauth/userinfo"))
    }

    // MARK: - Helpers

    /// Builds the `application/x-www-form-urlencoded` POST that RFC 6749 §4.1.3
    /// and §6 and RFC 7009 §2.1 define for the token and revocation endpoints.
    /// The payload's `CodingKeys` name the fields; `nil` fields are omitted.
    private func formPost(_ path: String, _ payload: some Encodable) throws -> APIRequest {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder.assinafy.encode(payload))
        guard let fields = object as? [String: String] else {
            throw AssinafySDKError("OAuth form fields must be strings")
        }
        let body = fields.sorted { $0.key < $1.key }
            .map { "\(formEncoded($0.key))=\(formEncoded($0.value))" }
            .joined(separator: "&")
        var request = APIRequest(
            method: .post,
            path: path,
            body: Data(body.utf8),
            contentType: "application/x-www-form-urlencoded",
            credential: .withheld
        )
        // The body carries a code or token; following a redirect would send it twice.
        request.followsRedirects = false
        return request
    }

    /// Rewrites a host-root path into an absolute URL on the configured API host.
    ///
    /// `/.well-known/…` is defined at the host root, so it must not inherit the
    /// `/v1` base path. Deriving it from the configured base URL keeps sandbox
    /// and self-hosted deployments working.
    private func hostRootURL(_ path: String) throws -> String {
        guard var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false) else {
            throw ValidationError("OAuth discovery requires a configured base URL")
        }
        components.path = path
        guard let url = components.url else {
            throw ValidationError("Failed to construct URL for path: \(path)")
        }
        return url.absoluteString
    }

    // MARK: - Objective-C / completion-handler API

    /// Fetches protected-resource metadata and delivers it on the **main queue**.
    @objc(protectedResourceMetadataWithCompletion:)
    public func protectedResourceMetadata(
        completion: @escaping (OAuthProtectedResourceMetadata?, Error?) -> Void
    ) {
        withCompletion({ try await self.protectedResourceMetadata() }, completion: completion)
    }

    /// Fetches authorization-server metadata and delivers it on the **main queue**.
    @objc(authorizationServerMetadataWithIssuer:completion:)
    public func authorizationServerMetadata(
        issuer: String,
        completion: @escaping (OAuthAuthorizationServerMetadata?, Error?) -> Void
    ) {
        withCompletion(
            { try await self.authorizationServerMetadata(issuer: issuer) },
            completion: completion
        )
    }

    /// Exchanges an authorization code and delivers the token on the **main queue**.
    @objc(exchangeAuthorizationCode:completion:)
    public func exchangeAuthorizationCode(
        _ payload: OAuthTokenPayload,
        completion: @escaping (OAuthTokenResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.exchangeAuthorizationCode(payload) }, completion: completion)
    }

    /// Refreshes an access token and delivers it on the **main queue**.
    @objc(refreshAccessToken:completion:)
    public func refreshAccessToken(
        _ payload: OAuthTokenPayload,
        completion: @escaping (OAuthTokenResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.refreshAccessToken(payload) }, completion: completion)
    }

    /// Revokes a token and notifies the **main queue** upon completion.
    @objc(revokeToken:completion:)
    public func revoke(
        _ payload: OAuthRevokePayload,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.revoke(payload) }, completion: completion)
    }

    /// Fetches userinfo claims and delivers them on the **main queue**.
    @objc(userInfoWithCompletion:)
    public func userInfo(completion: @escaping (OAuthUserInfo?, Error?) -> Void) {
        withCompletion({ try await self.userInfo() }, completion: completion)
    }
}

/// Percent-encodes everything outside the RFC 3986 unreserved set, so a `+`,
/// `&` or `=` inside a token survives form decoding unchanged.
private func formEncoded(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: formUnreserved) ?? value
}

private let formUnreserved = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
)
