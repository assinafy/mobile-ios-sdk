import XCTest
@testable import Assinafy

/// Pins the OAuth 2.1 authorization-code flow: PKCE generation, the authorize
/// URL, callback verification, and the four `/oauth` transport contracts.
final class OAuthResourceTests: XCTestCase {
    private var mock: MockHTTPClient!
    private var oauth: OAuthResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        oauth = OAuthResource(
            http: mock,
            apiBaseURL: URL(string: "https://api.assinafy.com.br/v1")!
        )
    }

    private func body(_ request: APIRequest?) -> [String: Any] {
        guard let data = request?.body,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }

    private func makeRequest(
        scopes: [OAuthScope] = [.documentsRead],
        resource: String? = nil
    ) -> OAuthAuthorizationRequest {
        OAuthAuthorizationRequest(
            clientId: "client-123",
            redirectURI: "myapp://oauth-callback",
            scopes: scopes,
            resource: resource
        )
    }

    // MARK: - PKCE

    func testPKCEVerifierMatchesRFC7636Grammar() {
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        for _ in 0..<50 {
            let pkce = OAuthPKCE()
            XCTAssertTrue((43...128).contains(pkce.codeVerifier.count))
            XCTAssertNil(pkce.codeVerifier.rangeOfCharacter(from: allowed.inverted))
            XCTAssertNil(pkce.codeChallenge.rangeOfCharacter(from: allowed.inverted))
            XCTAssertEqual(pkce.codeChallengeMethod, "S256")
        }
    }

    func testPKCEChallengeIsTheRFC7636S256Example() {
        // RFC 7636 appendix B: this verifier hashes to this challenge.
        let pkce = OAuthPKCE(codeVerifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        XCTAssertEqual(pkce.codeChallenge, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testPKCEVerifiersAreDistinctAcrossAttempts() {
        let verifiers = Set((0..<100).map { _ in OAuthPKCE().codeVerifier })
        XCTAssertEqual(verifiers.count, 100)
    }

    // MARK: - Authorization URL

    func testAuthorizationURLCarriesEveryRequiredParameter() throws {
        let request = OAuthAuthorizationRequest(
            clientId: "client-123",
            redirectURI: "myapp://oauth-callback",
            scopeStrings: [OAuthScope.documentsRead.rawValue, OAuthScope.webhooksWrite, OAuthScope.offlineAccess.rawValue],
            pkce: OAuthPKCE(),
            state: "state-123",
            resource: "https://api.assinafy.com.br"
        )
        let url = try XCTUnwrap(
            request.authorizationURL(endpoint: OAuthResource.defaultAuthorizationEndpoint)
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )

        XCTAssertEqual(components.host, "auth.assinafy.com.br")
        XCTAssertEqual(components.path, "/oauth/authorize")
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["client_id"], "client-123")
        XCTAssertEqual(items["redirect_uri"], "myapp://oauth-callback")
        XCTAssertEqual(items["state"], request.state)
        XCTAssertEqual(items["code_challenge"], request.pkce.codeChallenge)
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["scope"], "documents:read webhooks:write offline_access")
        XCTAssertEqual(items["resource"], "https://api.assinafy.com.br")
    }

    func testAuthorizationURLNeverLeaksTheCodeVerifier() throws {
        let request = makeRequest()
        let url = try XCTUnwrap(oauth.authorizationURL(for: request))
        XCTAssertFalse(url.absoluteString.contains(request.pkce.codeVerifier))
    }

    func testAuthorizationURLRejectsBlankAndNonHTTPSInput() {
        XCTAssertNil(makeRequest().authorizationURL(endpoint: "http://auth.assinafy.com.br/oauth/authorize"))
        XCTAssertNil(makeRequest().authorizationURL(endpoint: "not a url"))
        XCTAssertNil(
            OAuthAuthorizationRequest(clientId: " ", redirectURI: "myapp://cb", scopes: [])
                .authorizationURL(endpoint: OAuthResource.defaultAuthorizationEndpoint)
        )
    }

    // MARK: - Callback verification

    func testCallbackReturnsCodeWhenStateAndIssuerMatch() throws {
        let request = makeRequest()
        let url = URL(string: "myapp://oauth-callback?code=abc123&state=\(request.state)&iss=https://auth.assinafy.com.br")!
        let callback = try XCTUnwrap(OAuthCallback(callbackURL: url))
        let code = try callback.validate(against: request, issuer: "https://auth.assinafy.com.br")
        XCTAssertEqual(code, "abc123")
    }

    func testCallbackRejectsMismatchedState() throws {
        let request = makeRequest()
        let url = URL(string: "myapp://oauth-callback?code=abc123&state=not-the-state")!
        let callback = try XCTUnwrap(OAuthCallback(callbackURL: url))
        XCTAssertThrowsError(try callback.validate(against: request)) { error in
            XCTAssertTrue(error is ValidationError, "got \(type(of: error))")
        }
    }

    func testCallbackRejectsMissingState() throws {
        let request = makeRequest()
        let callback = try XCTUnwrap(
            OAuthCallback(callbackURL: URL(string: "myapp://oauth-callback?code=abc123")!)
        )
        XCTAssertThrowsError(try callback.validate(against: request))
    }

    func testCallbackRejectsMismatchedIssuer() throws {
        let request = makeRequest()
        let url = URL(string: "myapp://oauth-callback?code=abc&state=\(request.state)&iss=https://evil.example")!
        let callback = try XCTUnwrap(OAuthCallback(callbackURL: url))
        XCTAssertThrowsError(
            try callback.validate(against: request, issuer: "https://auth.assinafy.com.br")
        )
        // Without an expected issuer the same callback verifies on state alone.
        XCTAssertEqual(try callback.validate(against: request), "abc")
    }

    func testCallbackSurfacesServerReportedError() throws {
        let request = makeRequest()
        let url = URL(string: "myapp://oauth-callback?error=access_denied&error_description=User%20declined&state=\(request.state)")!
        let callback = try XCTUnwrap(OAuthCallback(callbackURL: url))
        XCTAssertThrowsError(try callback.validate(against: request)) { error in
            guard let apiError = error as? APIError else {
                return XCTFail("Expected APIError, got \(type(of: error))")
            }
            XCTAssertEqual(apiError.oauthError?.code, "access_denied")
            XCTAssertEqual(apiError.oauthError?.description, "User declined")
        }
    }

    func testCallbackWithoutCodeOrErrorIsRejected() throws {
        let request = makeRequest()
        let url = URL(string: "myapp://oauth-callback?state=\(request.state)")!
        let callback = try XCTUnwrap(OAuthCallback(callbackURL: url))
        XCTAssertThrowsError(try callback.validate(against: request))
    }

    // MARK: - Token exchange

    func testExchangeAuthorizationCodePostsFlatRFC6749Body() async throws {
        mock.stubJSON([
            "access_token": "at-1",
            "token_type": "Bearer",
            "expires_in": 3600,
            "refresh_token": "rt-1",
            "scope": "documents:read documents:write",
            "id_token": "idt-1",
        ])
        let verifier = OAuthPKCE().codeVerifier
        let token = try await oauth.exchangeAuthorizationCode(
            .authorizationCode(
                code: "code-1",
                redirectURI: "myapp://oauth-callback",
                codeVerifier: verifier,
                clientId: "client-123",
                resource: "https://api.assinafy.com.br"
            )
        )

        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/oauth/token")
        XCTAssertEqual(mock.lastRequest?.credential, .withheld)
        let sent = body(mock.lastRequest)
        XCTAssertEqual(sent["grant_type"] as? String, "authorization_code")
        XCTAssertEqual(sent["code"] as? String, "code-1")
        XCTAssertEqual(sent["redirect_uri"] as? String, "myapp://oauth-callback")
        XCTAssertEqual(sent["code_verifier"] as? String, verifier)
        XCTAssertEqual(sent["client_id"] as? String, "client-123")
        XCTAssertEqual(sent["resource"] as? String, "https://api.assinafy.com.br")
        XCTAssertNil(sent["client_secret"], "a public client must not send a secret")
        XCTAssertNil(sent["refresh_token"])

        XCTAssertEqual(token.accessToken, "at-1")
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.expiresIn, 3600)
        XCTAssertEqual(token.refreshToken, "rt-1")
        XCTAssertEqual(token.scopes, ["documents:read", "documents:write"])
        XCTAssertEqual(token.idToken, "idt-1")
    }

    func testTokenResponseDecodesWithoutOptionalFields() async throws {
        mock.stubJSON(["access_token": "at-1", "token_type": "Bearer", "expires_in": 600])
        let token = try await oauth.exchangeAuthorizationCode(
            .authorizationCode(
                code: "c",
                redirectURI: "myapp://cb",
                codeVerifier: OAuthPKCE().codeVerifier,
                clientId: "client-123"
            )
        )
        XCTAssertNil(token.refreshToken, "no refresh token without offline_access")
        XCTAssertNil(token.idToken)
        XCTAssertEqual(token.scopes, [])
        XCTAssertFalse(token.isExpired())
        XCTAssertEqual(
            token.expiresAt.timeIntervalSince(token.issuedAt),
            600,
            accuracy: 0.001
        )
    }

    func testAccessTokenExpiryUsesLeeway() {
        let token = OAuthTokenResponse(
            accessToken: "at",
            tokenType: "Bearer",
            expiresIn: 30,
            refreshToken: nil,
            scope: nil,
            idToken: nil
        )
        XCTAssertTrue(token.isExpired(), "30s of life is inside the default 60s leeway")
        XCTAssertFalse(token.isExpired(leeway: 0))
    }

    func testRefreshAccessTokenPostsRefreshGrant() async throws {
        mock.stubJSON(["access_token": "at-2", "token_type": "Bearer", "expires_in": 3600])
        _ = try await oauth.refreshAccessToken(
            .refreshToken("rt-1", clientId: "client-123")
        )
        XCTAssertEqual(mock.lastRequest?.path, "/oauth/token")
        let sent = body(mock.lastRequest)
        XCTAssertEqual(sent["grant_type"] as? String, "refresh_token")
        XCTAssertEqual(sent["refresh_token"] as? String, "rt-1")
        XCTAssertNil(sent["code"])
        XCTAssertNil(sent["code_verifier"])
    }

    func testTokenPayloadValidationRejectsIncompleteGrants() async {
        await assertThrowsValidationError {
            _ = try await self.oauth.exchangeAuthorizationCode(
                .authorizationCode(
                    code: "",
                    redirectURI: "myapp://cb",
                    codeVerifier: OAuthPKCE().codeVerifier,
                    clientId: "c"
                )
            )
        }
        await assertThrowsValidationError {
            _ = try await self.oauth.refreshAccessToken(.refreshToken("", clientId: "c"))
        }
        await assertThrowsValidationError {
            _ = try await self.oauth.exchangeAuthorizationCode(
                .authorizationCode(
                    code: "c",
                    redirectURI: "myapp://cb",
                    codeVerifier: OAuthPKCE().codeVerifier,
                    clientId: " "
                )
            )
        }
    }

    func testShortCodeVerifierIsRejectedBeforeAnyRequest() async {
        await assertThrowsValidationError {
            _ = try await self.oauth.exchangeAuthorizationCode(
                .authorizationCode(
                    code: "c",
                    redirectURI: "myapp://cb",
                    codeVerifier: "too-short",
                    clientId: "client-123"
                )
            )
        }
        XCTAssertNil(mock.lastRequest, "an invalid verifier must not reach the network")
    }

    // MARK: - Revocation

    func testRevokePostsTokenAndClient() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await oauth.revoke(
            OAuthRevokePayload(
                token: "at-1",
                clientId: "client-123",
                tokenTypeHint: OAuthTokenTypeHint.accessToken.rawValue
            )
        )
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/oauth/revoke")
        XCTAssertEqual(mock.lastRequest?.credential, .withheld)
        let sent = body(mock.lastRequest)
        XCTAssertEqual(sent["token"] as? String, "at-1")
        XCTAssertEqual(sent["client_id"] as? String, "client-123")
        XCTAssertEqual(sent["token_type_hint"] as? String, "access_token")
    }

    func testRevokeRequiresTokenAndClient() async {
        await assertThrowsValidationError {
            try await self.oauth.revoke(OAuthRevokePayload(token: " ", clientId: "c"))
        }
        await assertThrowsValidationError {
            try await self.oauth.revoke(OAuthRevokePayload(token: "t", clientId: " "))
        }
    }

    // MARK: - Userinfo

    func testUserInfoDecodesFlatClaimsAndKeepsTheBearerToken() async throws {
        mock.stubJSON([
            "sub": "d6zqpbyog2v3xvxerwn8la94",
            "name": "Maria Silva",
            "email": "maria@example.invalid",
            "email_verified": true,
        ])
        let info = try await oauth.userInfo()
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/oauth/userinfo")
        XCTAssertEqual(
            mock.lastRequest?.credential, .workspace,
            "userinfo authenticates with the OAuth access token as bearer"
        )
        XCTAssertEqual(info.sub, "d6zqpbyog2v3xvxerwn8la94")
        XCTAssertEqual(info.name, "Maria Silva")
        XCTAssertEqual(info.email, "maria@example.invalid")
        XCTAssertEqual(info.emailVerified?.boolValue, true)
    }

    func testUserInfoDecodesWithoutProfileOrEmailScopes() async throws {
        mock.stubJSON(["sub": "abc"])
        let info = try await oauth.userInfo()
        XCTAssertEqual(info.sub, "abc")
        XCTAssertNil(info.name)
        XCTAssertNil(info.email)
        XCTAssertNil(info.emailVerified)
    }

    // MARK: - Discovery

    func testProtectedResourceMetadataEscapesTheVersionedBasePath() async throws {
        mock.stubJSON([
            "resource": "https://api.assinafy.com.br",
            "authorization_servers": ["https://auth.assinafy.com.br"],
            "scopes_supported": ["documents:read", "documents:write"],
            "bearer_methods_supported": ["header"],
        ])
        let metadata = try await oauth.protectedResourceMetadata()
        XCTAssertEqual(
            mock.lastRequest?.path,
            "https://api.assinafy.com.br/.well-known/oauth-protected-resource",
            "the well-known path lives at the host root, not under /v1"
        )
        XCTAssertEqual(mock.lastRequest?.credential, .withheld)
        XCTAssertEqual(metadata.resource, "https://api.assinafy.com.br")
        XCTAssertEqual(metadata.authorizationServers, ["https://auth.assinafy.com.br"])
        XCTAssertEqual(metadata.bearerMethodsSupported, ["header"])
    }

    func testProtectedResourceMetadataFollowsTheConfiguredHost() async throws {
        let sandbox = OAuthResource(
            http: mock,
            apiBaseURL: URL(string: "https://sandbox.assinafy.com.br/v1")!
        )
        mock.stubJSON(["resource": "https://sandbox.assinafy.com.br"])
        _ = try await sandbox.protectedResourceMetadata()
        XCTAssertEqual(
            mock.lastRequest?.path,
            "https://sandbox.assinafy.com.br/.well-known/oauth-protected-resource"
        )
    }

    func testAuthorizationServerMetadataTargetsTheIssuerHost() async throws {
        mock.stubJSON([
            "issuer": "https://auth.assinafy.com.br",
            "authorization_endpoint": "https://auth.assinafy.com.br/oauth/authorize",
            "token_endpoint": "https://api.assinafy.com.br/v1/oauth/token",
            "revocation_endpoint": "https://api.assinafy.com.br/v1/oauth/revoke",
            "userinfo_endpoint": "https://api.assinafy.com.br/v1/oauth/userinfo",
            "jwks_uri": "https://auth.assinafy.com.br/.well-known/jwks.json",
            "scopes_supported": ["documents:read", "offline_access"],
            "response_types_supported": ["code"],
            "grant_types_supported": ["authorization_code", "refresh_token"],
            "code_challenge_methods_supported": ["S256"],
            "token_endpoint_auth_methods_supported": ["client_secret_post", "none"],
            "authorization_response_iss_parameter_supported": true,
        ])
        let metadata = try await oauth.authorizationServerMetadata()
        XCTAssertEqual(
            mock.lastRequest?.path,
            "https://auth.assinafy.com.br/.well-known/oauth-authorization-server"
        )
        XCTAssertEqual(mock.lastRequest?.credential, .withheld)
        XCTAssertEqual(metadata.issuer, "https://auth.assinafy.com.br")
        XCTAssertEqual(metadata.codeChallengeMethodsSupported, ["S256"])
        XCTAssertTrue(metadata.authorizationResponseISSParameterSupported)
        XCTAssertEqual(
            metadata.authorizationEndpoint,
            OAuthResource.defaultAuthorizationEndpoint,
            "the compiled-in default must match what production publishes"
        )
    }

    func testAuthorizationServerMetadataRejectsNonHTTPSIssuer() async {
        await assertThrowsValidationError {
            _ = try await self.oauth.authorizationServerMetadata(issuer: "http://auth.assinafy.com.br")
        }
    }

    // MARK: - Error surface

    func testOAuthErrorIsReadableFromAPIError() {
        let error = APIError.from(
            statusCode: 400,
            responseData: ["error": "invalid_grant", "error_description": "Code already used."]
        )
        XCTAssertEqual(error.oauthError?.code, "invalid_grant")
        XCTAssertEqual(error.oauthError?.description, "Code already used.")
        XCTAssertEqual(error.message, "invalid_grant")
    }

    func testNonOAuthAPIErrorHasNoOAuthDetail() {
        let error = APIError.from(statusCode: 404, responseData: ["message": "Not found"])
        XCTAssertNil(error.oauthError)
    }

    // MARK: - Client wiring

    func testClientExposesOAuthResource() {
        let client = AssinafyClient(apiKey: "key", defaultAccountId: "acc")
        XCTAssertNotNil(client.oauth)
    }
}
