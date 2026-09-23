import CryptoKit
import Foundation

// MARK: - OAuthScope

/// The scopes an Assinafy OAuth 2.1 access token can carry.
///
/// A token is granted only the scopes the user approved on the consent screen,
/// and is bound to a single workspace. Regardless of scope, an OAuth token can
/// never reach billing, account lifecycle, credential management, or admin
/// surfaces — those remain exclusive to `apiKeyAuth`/`bearerAuth`.
///
/// Requesting a scope the user declines is not an error: the token simply comes
/// back without it, and the first call that needs it answers `403` with a
/// `WWW-Authenticate: Bearer error="insufficient_scope"` header naming it.
public enum OAuthScope: String, Sendable, CaseIterable {
    /// Read documents, their pages, tags, signers, assignments and activity.
    case documentsRead = "documents:read"
    /// Create, update and delete documents, and manage their signers, assignments and activity.
    case documentsWrite = "documents:write"
    /// Read reusable document templates, their pages, roles, fields and tags.
    case templatesRead = "templates:read"
    /// Create, update and delete templates, their pages, roles, fields and tags.
    case templatesWrite = "templates:write"
    /// Read the workspace's profile, theme and logo.
    case accountRead = "account:read"
    /// Configure and deactivate the workspace webhook subscription.
    case webhooksWrite = "webhooks:write"
    /// Identify the authenticated user and enable ``OAuthResource/userInfo()``.
    case openID = "openid"
    /// Include the user's name in the `id_token` and userinfo claims.
    case profile = "profile"
    /// Include the user's email and its verification status in the claims.
    case email = "email"
    /// Request a refresh token, so the integration keeps working after the
    /// user's session expires without prompting them again.
    ///
    /// Granted only to a client that explicitly asks for it. It is a
    /// request-time signal rather than a permission, so it never appears in
    /// ``OAuthTokenResponse/scope``.
    case offlineAccess = "offline_access"
}

// MARK: - OAuthPKCE

/// A freshly generated RFC 7636 PKCE pair for one authorization attempt.
///
/// PKCE is **mandatory** on Assinafy's authorization server, which supports
/// `S256` only. Generate one value per authorization attempt, keep
/// ``codeVerifier`` in memory (never on disk, never in a URL, never logged),
/// send ``codeChallenge`` to the authorize endpoint, and pass the verifier to
/// ``OAuthResource/exchangeAuthorizationCode(_:)``.
///
/// ```swift
/// let pkce = OAuthPKCE()
/// // …send pkce.codeChallenge to /oauth/authorize, keep pkce.codeVerifier…
/// ```
@objcMembers
public final class OAuthPKCE: NSObject {
    /// The high-entropy secret held by the app: 43 characters from the RFC 7636
    /// unreserved alphabet. The token endpoint rejects anything outside the
    /// 43–128 character grammar with `invalid_grant`.
    public let codeVerifier: String
    /// The BASE64URL-encoded SHA-256 digest of ``codeVerifier``, sent to the
    /// authorize endpoint in place of the verifier itself.
    public let codeChallenge: String
    /// Always `S256`; Assinafy's authorization server does not accept `plain`.
    public let codeChallengeMethod = "S256"

    /// Generates a new PKCE pair from 256 bits of cryptographically secure randomness.
    @objc public override convenience init() {
        self.init(codeVerifier: OAuthPKCE.randomURLSafeToken())
    }

    /// Recreates a PKCE pair from a verifier retained across an authorization round trip.
    ///
    /// - Parameter codeVerifier: A verifier previously produced by ``init()``.
    @objc public init(codeVerifier: String) {
        self.codeVerifier = codeVerifier
        self.codeChallenge = OAuthPKCE.base64URL(
            Data(SHA256.hash(data: Data(codeVerifier.utf8)))
        )
    }

    /// Returns 256 bits of secure randomness as 43 BASE64URL characters.
    ///
    /// Also used for the `state` parameter, whose only requirement is that it
    /// be unguessable and single-use.
    public static func randomURLSafeToken() -> String {
        base64URL(SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) })
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension OAuthPKCE: @unchecked Sendable {}

// MARK: - OAuthAuthorizationRequest

/// Everything needed to build the browser URL that starts the authorization code flow.
///
/// Hand the URL from ``authorizationURL(endpoint:)`` to
/// `ASWebAuthenticationSession`, then match the callback's `state` against
/// ``state`` before exchanging the code.
@objcMembers
public final class OAuthAuthorizationRequest: NSObject {
    /// The client identifier issued when the integration was registered.
    public let clientId: String
    /// The exact redirect URI registered for ``clientId``.
    public let redirectURI: String
    /// Scopes to request. See ``OAuthScope``.
    public let scopes: [String]
    /// The PKCE pair for this attempt; retain it until the code is exchanged.
    public let pkce: OAuthPKCE
    /// An unguessable single-use value echoed back on the callback, which
    /// defends the redirect against cross-site request forgery.
    public let state: String
    /// Optional RFC 8707 resource indicator. When sent, it must equal
    /// ``OAuthProtectedResourceMetadata/resource`` and must be repeated
    /// identically at the token endpoint, or the exchange fails `invalid_target`.
    public let resource: String?

    /// Creates an authorization request.
    ///
    /// - Parameters:
    ///   - clientId: The registered client identifier.
    ///   - redirectURI: The registered redirect URI, matched exactly by the server.
    ///   - scopes: Scopes to request.
    ///   - pkce: A PKCE pair; a fresh one is generated when omitted.
    ///   - state: A CSRF token; a fresh one is generated when omitted.
    ///   - resource: Optional RFC 8707 resource indicator.
    public init(
        clientId: String,
        redirectURI: String,
        scopes: [OAuthScope],
        pkce: OAuthPKCE = OAuthPKCE(),
        state: String = OAuthPKCE.randomURLSafeToken(),
        resource: String? = nil
    ) {
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.scopes = scopes.map(\.rawValue)
        self.pkce = pkce
        self.state = state
        self.resource = resource
    }

    /// Creates an authorization request from raw scope strings, for Objective-C
    /// callers and for scopes added to the API after this SDK release.
    @objc(initWithClientId:redirectURI:scopeStrings:pkce:state:resource:)
    public init(
        clientId: String,
        redirectURI: String,
        scopeStrings: [String],
        pkce: OAuthPKCE,
        state: String,
        resource: String?
    ) {
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.scopes = scopeStrings
        self.pkce = pkce
        self.state = state
        self.resource = resource
    }

    /// Builds the browser URL for `endpoint`.
    ///
    /// - Parameter endpoint: The authorization endpoint, normally
    ///   ``OAuthResource/defaultAuthorizationEndpoint`` or the
    ///   `authorization_endpoint` from ``OAuthAuthorizationServerMetadata``.
    /// - Returns: The URL to open, or `nil` when a required value is blank or
    ///   `endpoint` is not an absolute HTTPS URL.
    @objc public func authorizationURL(endpoint: String) -> URL? {
        guard !clientId.isBlank, !redirectURI.isBlank, !state.isBlank,
              let base = AssinafyClientConfiguration.normalisedBaseURL(endpoint),
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var items = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.codeChallengeMethod),
        ]
        if !scopes.isEmpty {
            items.append(URLQueryItem(name: "scope", value: scopes.joined(separator: " ")))
        }
        if let resource, !resource.isBlank {
            items.append(URLQueryItem(name: "resource", value: resource))
        }
        components.queryItems = items
        return components.url
    }
}

extension OAuthAuthorizationRequest: @unchecked Sendable {}

// MARK: - OAuthCallback

/// The parsed result of the authorization server's redirect back to the app.
///
/// Build one with ``init(callbackURL:)``, then verify it with
/// ``validate(against:issuer:)`` before touching any of its values.
@objcMembers
public final class OAuthCallback: NSObject {
    /// The single-use authorization code, when the user approved the request.
    public let code: String?
    /// The `state` echoed by the server.
    public let state: String?
    /// The issuer identifier, when the server sent one (RFC 9207).
    public let issuer: String?
    /// The OAuth error code, when the user declined or the request was rejected.
    public let error: String?
    /// A human-readable description accompanying ``error``.
    public let errorDescription: String?

    /// Parses the query string of a redirect URI the app received.
    ///
    /// - Parameter callbackURL: The URL delivered to the app's redirect handler.
    /// - Returns: `nil` when `callbackURL` is not a URL.
    @objc public convenience init?(callbackURL: URL) {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value.flatMap { $0.isBlank ? nil : $0 }
        }
        self.init(
            code: value("code"),
            state: value("state"),
            issuer: value("iss"),
            error: value("error"),
            errorDescription: value("error_description")
        )
    }

    init(code: String?, state: String?, issuer: String?, error: String?, errorDescription: String?) {
        self.code = code
        self.state = state
        self.issuer = issuer
        self.error = error
        self.errorDescription = errorDescription
    }

    /// Verifies the callback against the request that produced it and returns
    /// the authorization code.
    ///
    /// Checks, in order: that the server did not report an error, that `state`
    /// matches ``OAuthAuthorizationRequest/state`` in constant time, and that a
    /// code is present. A mismatched `state` means the redirect did not come
    /// from the flow this app started, so the code is discarded unexchanged.
    ///
    /// - Parameters:
    ///   - request: The request whose ``OAuthAuthorizationRequest/state`` must match.
    ///   - issuer: When non-`nil`, also requires the server's RFC 9207 `iss`
    ///     parameter to equal it. Assinafy's authorization server always sends
    ///     `iss`, so passing ``OAuthAuthorizationServerMetadata/issuer`` here
    ///     additionally defends against a mix-up between authorization servers.
    /// - Returns: The authorization code, ready to exchange.
    /// - Throws: ``APIError`` carrying the server's OAuth error, or
    ///   ``ValidationError`` when the callback fails verification.
    public func validate(
        against request: OAuthAuthorizationRequest,
        issuer: String? = nil
    ) throws -> String {
        if let error {
            throw APIError(
                statusCode: 400,
                message: errorDescription ?? error,
                responseData: ["error": error, "error_description": errorDescription as Any]
            )
        }
        guard let state, constantTimeEquals(state, request.state) else {
            throw ValidationError("OAuth callback state does not match the authorization request")
        }
        if let issuer, !issuer.isBlank {
            guard let received = self.issuer, constantTimeEquals(received, issuer) else {
                throw ValidationError("OAuth callback issuer does not match the authorization server")
            }
        }
        guard let code, !code.isBlank else {
            throw ValidationError("OAuth callback contained no authorization code")
        }
        return code
    }
}

extension OAuthCallback: @unchecked Sendable {}

/// Compares two secrets without leaking their common prefix length through timing.
func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
    let a = Array(lhs.utf8), b = Array(rhs.utf8)
    guard a.count == b.count else { return false }
    var difference: UInt8 = 0
    for index in a.indices { difference |= a[index] ^ b[index] }
    return difference == 0
}

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - OAuthTokenPayload

/// Payload for `POST /oauth/token`.
///
/// Build it with ``authorizationCode(code:redirectURI:codeVerifier:clientId:clientSecret:resource:)``
/// or ``refreshToken(_:clientId:clientSecret:resource:)`` rather than by hand —
/// each grant type requires a different subset of these fields.
@objcMembers
public final class OAuthTokenPayload: NSObject, Encodable {
    /// `authorization_code` or `refresh_token`.
    public let grantType: String
    /// The single-use code from the callback. Authorization-code grant only.
    public let code: String?
    /// The same redirect URI sent to the authorize endpoint. Authorization-code grant only.
    public let redirectURI: String?
    /// The PKCE verifier for this attempt. Authorization-code grant only.
    public let codeVerifier: String?
    /// The refresh token to exchange. Refresh grant only.
    public let refreshToken: String?
    /// The registered client identifier. Required for both grants.
    public let clientId: String
    /// Confidential clients only. A public mobile client authenticates with
    /// PKCE and is never issued a secret — shipping one in an app bundle makes
    /// it extractable, so leave this `nil` on iOS.
    public let clientSecret: String?
    /// Optional RFC 8707 resource indicator; must match the one sent to the
    /// authorize endpoint.
    public let resource: String?

    init(
        grantType: String,
        code: String? = nil,
        redirectURI: String? = nil,
        codeVerifier: String? = nil,
        refreshToken: String? = nil,
        clientId: String,
        clientSecret: String? = nil,
        resource: String? = nil
    ) {
        self.grantType = grantType
        self.code = code
        self.redirectURI = redirectURI
        self.codeVerifier = codeVerifier
        self.refreshToken = refreshToken
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.resource = resource
    }

    /// Builds an `authorization_code` exchange.
    ///
    /// - Parameters:
    ///   - code: The code returned on the callback.
    ///   - redirectURI: The redirect URI sent to the authorize endpoint, repeated verbatim.
    ///   - codeVerifier: ``OAuthPKCE/codeVerifier`` from the same attempt.
    ///   - clientId: The registered client identifier.
    ///   - clientSecret: Confidential clients only; omit in a mobile app.
    ///   - resource: Optional RFC 8707 resource indicator.
    @objc public static func authorizationCode(
        code: String,
        redirectURI: String,
        codeVerifier: String,
        clientId: String,
        clientSecret: String? = nil,
        resource: String? = nil
    ) -> OAuthTokenPayload {
        OAuthTokenPayload(
            grantType: "authorization_code",
            code: code,
            redirectURI: redirectURI,
            codeVerifier: codeVerifier,
            clientId: clientId,
            clientSecret: clientSecret,
            resource: resource
        )
    }

    /// Builds a `refresh_token` exchange.
    ///
    /// - Parameters:
    ///   - refreshToken: The refresh token issued alongside a previous access token.
    ///   - clientId: The registered client identifier.
    ///   - clientSecret: Confidential clients only; omit in a mobile app.
    ///   - resource: Optional RFC 8707 resource indicator.
    @objc public static func refreshToken(
        _ refreshToken: String,
        clientId: String,
        clientSecret: String? = nil,
        resource: String? = nil
    ) -> OAuthTokenPayload {
        OAuthTokenPayload(
            grantType: "refresh_token",
            refreshToken: refreshToken,
            clientId: clientId,
            clientSecret: clientSecret,
            resource: resource
        )
    }

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case redirectURI = "redirect_uri"
        case codeVerifier = "code_verifier"
        case refreshToken = "refresh_token"
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case resource
    }

    /// Validates that the payload carries the fields its grant type requires.
    func validate() throws {
        guard !clientId.isBlank else { throw ValidationError("OAuth client ID is required") }
        switch grantType {
        case "authorization_code":
            guard code?.isBlank == false else {
                throw ValidationError("OAuth authorization code is required")
            }
            guard redirectURI?.isBlank == false else {
                throw ValidationError("OAuth redirect URI is required")
            }
            guard let verifier = codeVerifier, (43...128).contains(verifier.count) else {
                throw ValidationError(
                    "OAuth code verifier must be 43-128 characters (RFC 7636)"
                )
            }
        case "refresh_token":
            guard refreshToken?.isBlank == false else {
                throw ValidationError("OAuth refresh token is required")
            }
        default:
            throw ValidationError("Unsupported OAuth grant type: \(grantType)")
        }
    }
}

extension OAuthTokenPayload: @unchecked Sendable {}

// MARK: - OAuthRevokePayload

/// Payload for `POST /oauth/revoke`.
@objcMembers
public final class OAuthRevokePayload: NSObject, Encodable {
    /// The access or refresh token to revoke.
    public let token: String
    /// Optional `access_token` / `refresh_token` hint that lets the server look
    /// in the right store first.
    public let tokenTypeHint: String?
    /// The registered client identifier.
    public let clientId: String
    /// Confidential clients only.
    public let clientSecret: String?

    /// Creates a revocation payload.
    /// - Parameters:
    ///   - token: The token to revoke.
    ///   - clientId: The registered client identifier.
    ///   - tokenTypeHint: Optional hint; see ``OAuthTokenTypeHint``.
    ///   - clientSecret: Confidential clients only; omit in a mobile app.
    @objc public init(
        token: String,
        clientId: String,
        tokenTypeHint: String? = nil,
        clientSecret: String? = nil
    ) {
        self.token = token
        self.tokenTypeHint = tokenTypeHint
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    enum CodingKeys: String, CodingKey {
        case token
        case tokenTypeHint = "token_type_hint"
        case clientId = "client_id"
        case clientSecret = "client_secret"
    }
}

extension OAuthRevokePayload: @unchecked Sendable {}

/// Values accepted by ``OAuthRevokePayload/tokenTypeHint``.
public enum OAuthTokenTypeHint: String, Sendable {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
}

// MARK: - OAuthTokenResponse

/// The flat RFC 6749 §5.1 token response.
///
/// The token endpoint answers with `access_token` at the top level rather than
/// inside this API's usual `{status, message, data}` envelope, because no
/// standard OAuth client would look for it there.
@objcMembers
public final class OAuthTokenResponse: NSObject, Decodable {
    /// The bearer token to pass to `AssinafyClient(token:)`.
    public let accessToken: String
    /// Always `Bearer` in practice.
    public let tokenType: String
    /// Lifetime in seconds from issuance — typically 3600.
    public let expiresIn: Int
    /// Present only when ``OAuthScope/offlineAccess`` was both requested and
    /// consented. Without one, the user must authorize again once the access
    /// token expires.
    public let refreshToken: String?
    /// The space-separated scopes of the **access** token. `offline_access` is
    /// a request-time signal rather than a permission, so it never appears here.
    public let scope: String?
    /// A signed OIDC `id_token` (RS256), present only when ``OAuthScope/openID``
    /// was granted.
    public let idToken: String?
    /// When this response was decoded, which is the clock the SDK has closest
    /// to the moment the server issued the token.
    public let issuedAt: Date

    init(
        accessToken: String,
        tokenType: String,
        expiresIn: Int,
        refreshToken: String?,
        scope: String?,
        idToken: String?,
        issuedAt: Date = Date()
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.scope = scope
        self.idToken = idToken
        self.issuedAt = issuedAt
    }

    /// ``scope`` split into individual scope strings.
    public var scopes: [String] {
        scope?.split(separator: " ").map(String.init) ?? []
    }

    /// The moment ``accessToken`` expires: ``issuedAt`` plus ``expiresIn``.
    ///
    /// Refresh slightly before this — network latency and clock skew mean a
    /// token used at the last instant can still arrive expired.
    public var expiresAt: Date { issuedAt.addingTimeInterval(TimeInterval(expiresIn)) }

    /// Whether the access token is expired, or expires within `leeway` seconds.
    ///
    /// - Parameter leeway: Seconds of headroom; defaults to 60.
    public func isExpired(leeway: TimeInterval = 60) -> Bool {
        Date().addingTimeInterval(leeway) >= expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case idToken = "id_token"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            accessToken: try c.decode(String.self, forKey: .accessToken),
            tokenType: try c.decodeIfPresent(String.self, forKey: .tokenType) ?? "Bearer",
            expiresIn: try c.decodeIfPresent(Int.self, forKey: .expiresIn) ?? 0,
            refreshToken: try c.decodeIfPresent(String.self, forKey: .refreshToken),
            scope: try c.decodeIfPresent(String.self, forKey: .scope),
            idToken: try c.decodeIfPresent(String.self, forKey: .idToken)
        )
    }
}

extension OAuthTokenResponse: @unchecked Sendable {}

// MARK: - OAuthUserInfo

/// OpenID Connect claims about the user who authorized the token.
///
/// Returned flat, per OIDC Core §5.3.2, rather than inside the API envelope.
@objcMembers
public final class OAuthUserInfo: NSObject, Decodable {
    /// The stable subject identifier. Always present; requires ``OAuthScope/openID``.
    public let sub: String
    /// The user's name. Requires ``OAuthScope/profile``.
    public let name: String?
    /// The user's email. Requires ``OAuthScope/email``.
    public let email: String?
    /// Whether that email is verified. Requires ``OAuthScope/email``.
    public let emailVerified: NSNumber?

    init(sub: String, name: String?, email: String?, emailVerified: Bool?) {
        self.sub = sub
        self.name = name
        self.email = email
        self.emailVerified = emailVerified.map(NSNumber.init(value:))
    }

    enum CodingKeys: String, CodingKey {
        case sub, name, email
        case emailVerified = "email_verified"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sub: try c.decode(String.self, forKey: .sub),
            name: try c.decodeIfPresent(String.self, forKey: .name),
            email: try c.decodeIfPresent(String.self, forKey: .email),
            emailVerified: try c.decodeIfPresent(Bool.self, forKey: .emailVerified)
        )
    }
}

extension OAuthUserInfo: @unchecked Sendable {}

// MARK: - OAuthProtectedResourceMetadata

/// RFC 9728 metadata describing the API as an OAuth protected resource.
///
/// Returned bare, per RFC 8615, rather than inside the API envelope.
@objcMembers
public final class OAuthProtectedResourceMetadata: NSObject, Decodable {
    /// The canonical resource identifier, and the only valid RFC 8707
    /// `resource` value for this API.
    public let resource: String
    /// The authorization servers that can issue tokens for this API. Fetch
    /// `.well-known/oauth-authorization-server` from the first entry.
    public let authorizationServers: [String]
    /// Scopes this resource accepts. Deliberately excludes `offline_access`,
    /// which is a client concern rather than something the resource protects.
    public let scopesSupported: [String]
    /// How a token may be presented; `header` in practice.
    public let bearerMethodsSupported: [String]

    init(
        resource: String,
        authorizationServers: [String],
        scopesSupported: [String],
        bearerMethodsSupported: [String]
    ) {
        self.resource = resource
        self.authorizationServers = authorizationServers
        self.scopesSupported = scopesSupported
        self.bearerMethodsSupported = bearerMethodsSupported
    }

    enum CodingKeys: String, CodingKey {
        case resource
        case authorizationServers = "authorization_servers"
        case scopesSupported = "scopes_supported"
        case bearerMethodsSupported = "bearer_methods_supported"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            resource: try c.decode(String.self, forKey: .resource),
            authorizationServers: try c.decodeIfPresent([String].self, forKey: .authorizationServers) ?? [],
            scopesSupported: try c.decodeIfPresent([String].self, forKey: .scopesSupported) ?? [],
            bearerMethodsSupported: try c.decodeIfPresent([String].self, forKey: .bearerMethodsSupported) ?? []
        )
    }
}

extension OAuthProtectedResourceMetadata: @unchecked Sendable {}

// MARK: - OAuthAuthorizationServerMetadata

/// RFC 8414 metadata published by the authorization server.
///
/// This is the authoritative source for the endpoint URLs; prefer it over the
/// SDK's compiled-in defaults, which exist only so a first call can be made.
@objcMembers
public final class OAuthAuthorizationServerMetadata: NSObject, Decodable {
    /// The issuer identifier, matched against the callback's RFC 9207 `iss`.
    public let issuer: String
    /// Where to send the user's browser to start the flow.
    public let authorizationEndpoint: String
    /// Where to exchange a code or refresh token.
    public let tokenEndpoint: String
    /// Where to revoke a token.
    public let revocationEndpoint: String?
    /// Where to read OpenID Connect claims.
    public let userinfoEndpoint: String?
    /// Where to fetch the keys that sign `id_token`s.
    public let jwksURI: String?
    /// Every scope the server can issue, `offline_access` included.
    public let scopesSupported: [String]
    /// Supported `response_type` values; `code` only.
    public let responseTypesSupported: [String]
    /// Supported grant types.
    public let grantTypesSupported: [String]
    /// Supported PKCE methods; `S256` only.
    public let codeChallengeMethodsSupported: [String]
    /// How a client may authenticate at the token endpoint. A mobile app uses
    /// `none` and relies on PKCE.
    public let tokenEndpointAuthMethodsSupported: [String]
    /// Whether the server returns the RFC 9207 `iss` parameter on the callback.
    public let authorizationResponseISSParameterSupported: Bool

    init(
        issuer: String,
        authorizationEndpoint: String,
        tokenEndpoint: String,
        revocationEndpoint: String?,
        userinfoEndpoint: String?,
        jwksURI: String?,
        scopesSupported: [String],
        responseTypesSupported: [String],
        grantTypesSupported: [String],
        codeChallengeMethodsSupported: [String],
        tokenEndpointAuthMethodsSupported: [String],
        authorizationResponseISSParameterSupported: Bool
    ) {
        self.issuer = issuer
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.revocationEndpoint = revocationEndpoint
        self.userinfoEndpoint = userinfoEndpoint
        self.jwksURI = jwksURI
        self.scopesSupported = scopesSupported
        self.responseTypesSupported = responseTypesSupported
        self.grantTypesSupported = grantTypesSupported
        self.codeChallengeMethodsSupported = codeChallengeMethodsSupported
        self.tokenEndpointAuthMethodsSupported = tokenEndpointAuthMethodsSupported
        self.authorizationResponseISSParameterSupported = authorizationResponseISSParameterSupported
    }

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case revocationEndpoint = "revocation_endpoint"
        case userinfoEndpoint = "userinfo_endpoint"
        case jwksURI = "jwks_uri"
        case scopesSupported = "scopes_supported"
        case responseTypesSupported = "response_types_supported"
        case grantTypesSupported = "grant_types_supported"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
        case tokenEndpointAuthMethodsSupported = "token_endpoint_auth_methods_supported"
        case authorizationResponseISSParameterSupported = "authorization_response_iss_parameter_supported"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            issuer: try c.decode(String.self, forKey: .issuer),
            authorizationEndpoint: try c.decode(String.self, forKey: .authorizationEndpoint),
            tokenEndpoint: try c.decode(String.self, forKey: .tokenEndpoint),
            revocationEndpoint: try c.decodeIfPresent(String.self, forKey: .revocationEndpoint),
            userinfoEndpoint: try c.decodeIfPresent(String.self, forKey: .userinfoEndpoint),
            jwksURI: try c.decodeIfPresent(String.self, forKey: .jwksURI),
            scopesSupported: try c.decodeIfPresent([String].self, forKey: .scopesSupported) ?? [],
            responseTypesSupported: try c.decodeIfPresent([String].self, forKey: .responseTypesSupported) ?? [],
            grantTypesSupported: try c.decodeIfPresent([String].self, forKey: .grantTypesSupported) ?? [],
            codeChallengeMethodsSupported: try c.decodeIfPresent(
                [String].self, forKey: .codeChallengeMethodsSupported
            ) ?? [],
            tokenEndpointAuthMethodsSupported: try c.decodeIfPresent(
                [String].self, forKey: .tokenEndpointAuthMethodsSupported
            ) ?? [],
            authorizationResponseISSParameterSupported: try c.decodeIfPresent(
                Bool.self, forKey: .authorizationResponseISSParameterSupported
            ) ?? false
        )
    }
}

extension OAuthAuthorizationServerMetadata: @unchecked Sendable {}

// MARK: - OAuthErrorDetail

/// The flat `{error, error_description}` body an OAuth endpoint returns on failure.
///
/// Read it from ``APIError/oauthError`` rather than parsing
/// ``APIError/responseData`` by hand.
public struct OAuthErrorDetail: Sendable, Equatable {
    /// The RFC 6749 error code, such as `invalid_grant` or `invalid_client`.
    public let code: String
    /// The server's human-readable explanation, when it sent one.
    ///
    /// `invalid_client` descriptions never reveal whether a `client_id` exists.
    public let description: String?

    /// Creates an OAuth error detail.
    public init(code: String, description: String?) {
        self.code = code
        self.description = description
    }
}

public extension APIError {
    /// The OAuth error carried by a failed `/oauth/*` call, or `nil` for any
    /// other API error.
    var oauthError: OAuthErrorDetail? {
        guard let object = responseData as? [String: Any],
              let code = object["error"] as? String, !code.isEmpty else { return nil }
        return OAuthErrorDetail(
            code: code,
            description: object["error_description"] as? String
        )
    }
}
