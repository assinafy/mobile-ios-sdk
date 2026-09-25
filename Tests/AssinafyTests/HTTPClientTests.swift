import XCTest
@testable import Assinafy

final class HTTPClientTests: XCTestCase {
    private final class ProtocolState: @unchecked Sendable {
        typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

        private let lock = NSLock()
        private var handler: Handler?

        func set(_ handler: @escaping Handler) {
            lock.withLock { self.handler = handler }
        }

        func response(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
            let current = lock.withLock { handler }
            guard let current else { throw URLError(.badServerResponse) }
            return try current(request)
        }
    }

    private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
        static let state = ProtocolState()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            do {
                let (response, data) = try Self.state.response(for: request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    private final class RedirectState: @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [URLRequest] = []
        private var status = 302

        func reset(status: Int = 302) { lock.withLock { recorded = []; self.status = status } }
        func redirectStatus() -> Int { lock.withLock { status } }
        func record(_ request: URLRequest) { lock.withLock { recorded.append(request) } }
        func requests() -> [URLRequest] { lock.withLock { recorded } }
    }

    /// Redirects every request to the same path under `/moved` on the same
    /// origin, with the status set by `reset(status:)`, and answers there with
    /// a token response, so a followed redirect looks like a success.
    private final class SameOriginRedirectURLProtocol: URLProtocol, @unchecked Sendable {
        static let state = RedirectState()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.state.record(request)
            let url = request.url!
            guard !url.path.hasPrefix("/moved") else {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(
                    #"{"access_token":"at-2","token_type":"Bearer","expires_in":3600,"refresh_token":"rt-2"}"#.utf8
                ))
                client?.urlProtocolDidFinishLoading(self)
                return
            }
            var redirect = request
            redirect.url = URL(string: "https://sandbox.example.test/moved" + url.path)!
            let response = HTTPURLResponse(
                url: url,
                statusCode: Self.state.redirectStatus(),
                httpVersion: nil,
                headerFields: ["Location": redirect.url!.absoluteString]
            )!
            client?.urlProtocol(self, wasRedirectedTo: redirect, redirectResponse: response)
            // What an HTTP load does when the redirect is refused: the 3xx
            // itself completes the task. A followed redirect ignores it.
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private final class RedirectURLProtocol: URLProtocol, @unchecked Sendable {
        static let state = RedirectState()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.state.record(request)
            guard request.url?.host == "sandbox.example.test" else {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data("ok".utf8))
                client?.urlProtocolDidFinishLoading(self)
                return
            }
            let redirect = URLRequest(url: URL(string: "https://downloads.example.test/file.pdf")!)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 302,
                httpVersion: nil,
                headerFields: ["Location": redirect.url!.absoluteString]
            )!
            client?.urlProtocol(self, wasRedirectedTo: redirect, redirectResponse: response)
        }

        override func stopLoading() {}
    }

    private func transport(headers: [String: String] = [:]) -> URLSessionHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSessionHTTPClient(
            baseURL: URL(string: "https://sandbox.example.test/v1/")!,
            defaultHeaders: headers,
            session: URLSession(configuration: configuration)
        )
    }

    func testBuildURLRequestEncodesPathQueryHeadersAndBody() throws {
        let client = transport(headers: ["X-Api-Key": "secret", "Accept": "application/json"])
        let request = APIRequest(
            method: .put,
            path: "/documents/doc-1",
            queryItems: [URLQueryItem(name: "search", value: "two words")],
            body: Data("{}".utf8)
        )

        let built = try client.buildURLRequest(from: request)
        XCTAssertEqual(built.url?.absoluteString, "https://sandbox.example.test/v1/documents/doc-1?search=two%20words")
        XCTAssertEqual(built.httpMethod, "PUT")
        XCTAssertEqual(built.value(forHTTPHeaderField: "X-Api-Key"), "secret")
        XCTAssertEqual(built.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(built.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(built.httpBody, Data("{}".utf8))
    }

    func testPerformReturnsSuccessfulResponse() async throws {
        StubURLProtocol.state.set { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["X-Pagination-Current-Page": "1"]
            )!
            return (response, Data("{\"ok\":true}".utf8))
        }

        let response = try await transport().perform(.get("/health"))
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(String(data: response.data, encoding: .utf8), "{\"ok\":true}")
    }

    func testDefaultSessionRequiresTLS12() {
        let session = URLSessionHTTPClient.makeSession(timeout: 30)
        XCTAssertEqual(session.configuration.tlsMinimumSupportedProtocolVersion, .TLSv12)
    }

    func testPerformPreservesJSONAndTextErrorBodies() async {
        StubURLProtocol.state.set { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 422, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"message\":\"Invalid payload\"}".utf8))
        }

        do {
            _ = try await transport().perform(.get("/failure"))
            XCTFail("Expected APIError")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 422)
            XCTAssertEqual(error.message, "Invalid payload")
            XCTAssertNotNil(error.responseData as? [String: Any])
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }

        StubURLProtocol.state.set { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data("temporarily unavailable".utf8))
        }

        do {
            _ = try await transport().perform(.get("/failure"))
            XCTFail("Expected APIError")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 503)
            XCTAssertEqual(error.message, "temporarily unavailable")
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func testPerformMapsTransportFailure() async {
        // A refused TLS 1.0/1.1 handshake is a connection error, never an HTTP status.
        for code in [URLError.Code.timedOut, .secureConnectionFailed] {
            StubURLProtocol.state.set { _ in throw URLError(code) }

            do {
                _ = try await transport().perform(.get("/timeout"))
                XCTFail("Expected NetworkError")
            } catch let error as NetworkError {
                XCTAssertEqual((error.underlyingError as? URLError)?.code, code)
            } catch {
                XCTFail("Expected NetworkError, got \(error)")
            }
        }
    }

    func testInsufficientScopeIsReadFromTheWWWAuthenticateChallenge() async {
        let challenges: [(Int, String?, String?)] = [
            (403, #"Bearer error="insufficient_scope", scope="documents:write", resource_metadata="https://api.assinafy.com.br/.well-known/oauth-protected-resource""#, "documents:write"),
            (403, nil, nil),
            (401, #"Bearer error="invalid_token""#, nil),
        ]
        for (status, challenge, expected) in challenges {
            StubURLProtocol.state.set { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: challenge.map { ["WWW-Authenticate": $0] }
                )!
                return (response, Data(#"{"status":\#(status),"message":"Forbidden","data":null}"#.utf8))
            }

            do {
                _ = try await transport().perform(.get("/documents"))
                XCTFail("Expected APIError")
            } catch let error as APIError {
                XCTAssertEqual(error.insufficientScope, expected, "\(status) \(challenge ?? "no challenge")")
            } catch {
                XCTFail("Expected APIError, got \(error)")
            }
        }
    }

    func testSameOriginRedirectKeepsAuthentication() {
        let client = transport()
        var request = URLRequest(url: URL(string: "https://sandbox.example.test/v1/next")!)
        request.httpMethod = "GET"
        request.setValue("secret", forHTTPHeaderField: "X-Api-Key")

        let redirected = client.redirectedRequest(request)

        XCTAssertEqual(redirected?.value(forHTTPHeaderField: "X-Api-Key"), "secret")
    }

    func testCrossOriginDownloadRedirectStripsAuthentication() {
        let client = transport()
        var request = URLRequest(url: URL(string: "https://downloads.example.test/file.pdf")!)
        request.httpMethod = "GET"
        request.setValue("secret", forHTTPHeaderField: "X-Api-Key")
        request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        request.setValue("private-value", forHTTPHeaderField: "X-Custom-Secret")
        request.setValue("assinafy-ios-sdk/test", forHTTPHeaderField: "User-Agent")

        let redirected = client.redirectedRequest(request)

        XCTAssertNotNil(redirected)
        XCTAssertNil(redirected?.value(forHTTPHeaderField: "X-Api-Key"))
        XCTAssertNil(redirected?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(redirected?.value(forHTTPHeaderField: "X-Custom-Secret"))
        XCTAssertEqual(redirected?.value(forHTTPHeaderField: "User-Agent"), "assinafy-ios-sdk/test")
    }

    func testUnsafeCrossOriginRedirectsAreBlocked() {
        let client = transport()
        var bodyRedirect = URLRequest(url: URL(string: "https://other.example.test/collect")!)
        bodyRedirect.httpMethod = "POST"
        var downgrade = URLRequest(url: URL(string: "http://downloads.example.test/file.pdf")!)
        downgrade.httpMethod = "GET"
        var userInfo = URLRequest(url: URL(string: "https://user@downloads.example.test/file.pdf")!)
        userInfo.httpMethod = "GET"

        XCTAssertNil(client.redirectedRequest(bodyRedirect))
        XCTAssertNil(client.redirectedRequest(downgrade))
        XCTAssertNil(client.redirectedRequest(userInfo))
    }

    func testPublicTransportInitializerFailsClosedForUnsafeConfiguration() async {
        for client in [
            URLSessionHTTPClient(baseURL: URL(string: "http://api.example.test/v1")!),
            URLSessionHTTPClient(baseURL: URL(string: "https://api.example.test/v1")!, timeout: 0),
            URLSessionHTTPClient(baseURL: URL(string: "file:///private/tmp/api")!),
        ] {
            do {
                _ = try await client.perform(.get("/probe"))
                XCTFail("Expected ValidationError")
            } catch is ValidationError {
            } catch {
                XCTFail("Expected ValidationError, got \(error)")
            }
        }
    }

    func testTransportRedirectDelegateDoesNotForwardCredentials() async throws {
        RedirectURLProtocol.state.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedirectURLProtocol.self]
        let client = URLSessionHTTPClient(
            baseURL: URL(string: "https://sandbox.example.test/v1")!,
            defaultHeaders: [
                "X-Api-Key": "secret",
                "Authorization": "Bearer secret",
                "Accept": "application/pdf",
            ],
            session: URLSession(configuration: configuration)
        )

        _ = try await client.perform(.get("/redirect"))

        let requests = RedirectURLProtocol.state.requests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.url?.host, "downloads.example.test")
        XCTAssertNil(requests.last?.value(forHTTPHeaderField: "X-Api-Key"))
        XCTAssertNil(requests.last?.value(forHTTPHeaderField: "Authorization"))
    }

    func testOAuthTokenRequestsRefuseRedirects() async {
        // A 307 or 308 repeats the POST body, and the refresh token in it may
        // already be retired: the 3xx must come back as an error, unfollowed.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SameOriginRedirectURLProtocol.self]
        configuration.timeoutIntervalForRequest = 5
        let baseURL = URL(string: "https://sandbox.example.test/v1")!
        let oauth = OAuthResource(
            http: URLSessionHTTPClient(
                baseURL: baseURL,
                defaultHeaders: [:],
                session: URLSession(configuration: configuration)
            ),
            apiBaseURL: baseURL
        )
        let calls: [(String, () async throws -> Void)] = [
            ("exchange", {
                _ = try await oauth.exchangeAuthorizationCode(.authorizationCode(
                    code: "code-1",
                    redirectURI: "https://app.example.invalid/oauth/callback",
                    codeVerifier: OAuthPKCE().codeVerifier,
                    clientId: "client-123"
                ))
            }),
            ("refresh", { _ = try await oauth.refreshAccessToken(.refreshToken("rt-1", clientId: "client-123")) }),
            ("revoke", { try await oauth.revoke(OAuthRevokePayload(token: "rt-1", clientId: "client-123")) }),
        ]
        for status in [307, 308] {
            for (name, call) in calls {
                SameOriginRedirectURLProtocol.state.reset(status: status)
                do {
                    try await call()
                    XCTFail("\(name) followed a \(status)")
                } catch let error as APIError {
                    XCTAssertEqual(error.statusCode, status, name)
                } catch {
                    XCTFail("\(name): expected APIError, got \(error)")
                }
                XCTAssertEqual(SameOriginRedirectURLProtocol.state.requests().count, 1, "\(name) \(status)")
            }
        }
    }

    func testCrossOriginRedirectRejectsRequestBody() {
        let client = URLSessionHTTPClient(baseURL: URL(string: "https://api.example.test/v1")!)
        var request = URLRequest(url: URL(string: "https://downloads.example.test/file")!)
        request.httpMethod = "GET"
        request.httpBody = Data("secret".utf8)

        XCTAssertNil(client.redirectedRequest(request))
    }

    func testCancelledTransportPreservesTaskCancellation() async {
        StubURLProtocol.state.set { _ in throw URLError(.cancelled) }

        do {
            _ = try await transport().perform(.get("/cancelled"))
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}
