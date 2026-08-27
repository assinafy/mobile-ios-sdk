import Foundation

// MARK: - HTTPMethod

/// HTTP verbs used internally by the SDK.
@objc public enum HTTPMethod: Int, Sendable {
    case get, post, put, patch, delete

    var httpValue: String {
        switch self {
        case .get:    return "GET"
        case .post:   return "POST"
        case .put:    return "PUT"
        case .patch:  return "PATCH"
        case .delete: return "DELETE"
        }
    }
}

// MARK: - APIRequest

/// An immutable value describing a single HTTP request.
///
/// Construct instances using the static factory methods
/// (`get(_:)`, `post(_:body:)`, `put(_:body:)`, `patch(_:body:)`, `delete(_:)`).
public struct APIRequest: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let queryItems: [URLQueryItem]?
    public let body: Data?
    public let contentType: String

    /// Creates an HTTP request.
    /// - Parameters:
    ///   - method: HTTP verb.
    ///   - path: API-relative path.
    ///   - queryItems: Optional URL query parameters.
    ///   - body: Optional encoded request body.
    ///   - contentType: Request body media type.
    public init(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        contentType: String = "application/json"
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.body = body
        self.contentType = contentType
    }

    /// Creates a GET request for `path` with optional query parameters.
    public static func get(_ path: String, queryItems: [URLQueryItem]? = nil) -> APIRequest {
        APIRequest(method: .get, path: path, queryItems: queryItems)
    }

    /// Creates a DELETE request for `path` with optional query parameters.
    public static func delete(_ path: String, queryItems: [URLQueryItem]? = nil) -> APIRequest {
        APIRequest(method: .delete, path: path, queryItems: queryItems)
    }

    /// Creates a DELETE request with a JSON-encoded body.
    /// - Throws: An encoding error when `body` cannot be encoded.
    public static func delete<B: Encodable>(_ path: String, body: B) throws -> APIRequest {
        let data = try JSONEncoder.assinafy.encode(body)
        return APIRequest(method: .delete, path: path, body: data)
    }

    /// Creates a POST request with a JSON-encoded body.
    /// - Throws: An encoding error when `body` cannot be encoded.
    public static func post<B: Encodable>(_ path: String, body: B) throws -> APIRequest {
        let data = try JSONEncoder.assinafy.encode(body)
        return APIRequest(method: .post, path: path, body: data)
    }

    /// Creates a POST request without a body.
    public static func post(_ path: String) -> APIRequest {
        APIRequest(method: .post, path: path)
    }

    /// Creates a PUT request with a JSON-encoded body.
    /// - Throws: An encoding error when `body` cannot be encoded.
    public static func put<B: Encodable>(_ path: String, body: B) throws -> APIRequest {
        let data = try JSONEncoder.assinafy.encode(body)
        return APIRequest(method: .put, path: path, body: data)
    }

    /// Creates a PUT request without a body.
    public static func put(_ path: String) -> APIRequest {
        APIRequest(method: .put, path: path)
    }

    /// Creates a PUT request with a JSON body and query parameters.
    /// - Throws: An encoding error when `body` cannot be encoded.
    public static func put<B: Encodable>(_ path: String, body: B, queryItems: [URLQueryItem]) throws -> APIRequest {
        let data = try JSONEncoder.assinafy.encode(body)
        return APIRequest(method: .put, path: path, queryItems: queryItems, body: data)
    }

    /// Creates a PATCH request with a JSON-encoded body.
    /// - Throws: An encoding error when `body` cannot be encoded.
    public static func patch<B: Encodable>(_ path: String, body: B) throws -> APIRequest {
        let data = try JSONEncoder.assinafy.encode(body)
        return APIRequest(method: .patch, path: path, body: data)
    }

    /// Creates a PATCH request without a body.
    public static func patch(_ path: String) -> APIRequest {
        APIRequest(method: .patch, path: path)
    }
}

// MARK: - APIResponse

/// Carries the raw body, headers, and status code of a successful HTTP response.
public struct APIResponse: @unchecked Sendable {
    /// Raw response body.
    public let data: Data
    /// All response headers, keyed by `AnyHashable`.
    public let headers: [AnyHashable: Any]
    /// HTTP status code (2xx when returned from the client).
    public let statusCode: Int

    /// Creates a transport response. Primarily useful for custom transports and tests.
    public init(data: Data, headers: [AnyHashable: Any] = [:], statusCode: Int) {
        self.data = data
        self.headers = headers
        self.statusCode = statusCode
    }
}

// MARK: - HTTPClientProtocol

/// Abstraction over the HTTP transport layer, enabling mock injection in tests.
public protocol HTTPClientProtocol: AnyObject {
    /// Sends `request` and returns the raw response.
    ///
    /// - Throws: ``APIError`` for non-2xx status codes,
    ///           ``NetworkError`` for transport-level failures.
    func perform(_ request: APIRequest) async throws -> APIResponse
}

// MARK: - URLSessionHTTPClient

/// Production HTTP client backed by `URLSession`.
///
/// Instantiated internally by ``AssinafyClient`` and not intended for direct use.
public final class URLSessionHTTPClient: NSObject, HTTPClientProtocol, URLSessionTaskDelegate, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: URL
    private let defaultHeaders: [String: String]
    private let configurationError: ValidationError?

    /// Creates a URL-session transport.
    /// - Parameters:
    ///   - baseURL: Base URL against which request paths are resolved.
    ///   - defaultHeaders: Headers included with every request.
    ///   - timeout: Per-request timeout in seconds.
    public convenience init(
        baseURL: URL,
        defaultHeaders: [String: String] = [:],
        timeout: TimeInterval = 30
    ) {
        let normalisedURL = AssinafyClientConfiguration.normalisedBaseURL(baseURL.absoluteString)
        let configurationError: ValidationError?
        if normalisedURL == nil {
            configurationError = ValidationError(
                "Base URL must be an absolute HTTPS URL without credentials, query, or fragment"
            )
        } else if !timeout.isFinite || timeout <= 0 {
            configurationError = ValidationError("Timeout must be a finite positive interval")
        } else {
            configurationError = nil
        }
        self.init(
            baseURL: normalisedURL
                ?? URL(string: AssinafyClientConfiguration.productionBaseURL)!,
            defaultHeaders: defaultHeaders,
            session: Self.makeSession(timeout: configurationError == nil ? timeout : 30),
            configurationError: configurationError
        )
    }

    convenience init(
        baseURL: URL,
        defaultHeaders: [String: String],
        timeout: TimeInterval,
        configurationError: ValidationError?
    ) {
        self.init(
            baseURL: baseURL,
            defaultHeaders: defaultHeaders,
            session: Self.makeSession(timeout: timeout),
            configurationError: configurationError
        )
    }

    private static func makeSession(timeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }

    init(
        baseURL: URL,
        defaultHeaders: [String: String],
        session: URLSession,
        configurationError: ValidationError? = nil
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.session = session
        self.configurationError = configurationError
        super.init()
    }

    public func perform(_ request: APIRequest) async throws -> APIResponse {
        if let configurationError { throw configurationError }
        let urlRequest = try buildURLRequest(from: request)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest, delegate: self)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw NetworkError(
                "Network request failed: \(error.localizedDescription)",
                underlyingError: error
            )
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError("Invalid response from server")
        }
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let parsed: Any?
            if data.isEmpty {
                parsed = nil
            } else if let json = try? JSONSerialization.jsonObject(with: data) {
                parsed = json
            } else {
                parsed = String(data: data, encoding: .utf8)
            }
            throw APIError.from(statusCode: httpResponse.statusCode, responseData: parsed)
        }
        return APIResponse(
            data: data,
            headers: httpResponse.allHeaderFields,
            statusCode: httpResponse.statusCode
        )
    }

    func buildURLRequest(from request: APIRequest) throws -> URLRequest {
        let base = baseURL.absoluteString.hasSuffix("/")
            ? baseURL
            : URL(string: baseURL.absoluteString + "/")!

        let pathStripped = request.path.hasPrefix("/")
            ? String(request.path.dropFirst())
            : request.path

        guard var components = URLComponents(
            string: base.appendingPathComponent(pathStripped).absoluteString
        ) else {
            throw ValidationError("Invalid URL path: \(request.path)")
        }

        if let items = request.queryItems, !items.isEmpty {
            components.queryItems = items
        }

        guard let url = components.url else {
            throw ValidationError("Failed to construct URL for path: \(request.path)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.httpValue
        urlRequest.httpBody   = request.body

        for (key, value) in defaultHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        if request.body != nil || request.method != .get {
            urlRequest.setValue(request.contentType, forHTTPHeaderField: "Content-Type")
        }

        return urlRequest
    }

    /// Allows safe download redirects without forwarding Assinafy credentials
    /// to another origin. Non-HTTPS and cross-origin body redirects are refused.
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(redirectedRequest(request))
    }

    func redirectedRequest(_ request: URLRequest) -> URLRequest? {
        guard let url = request.url,
              url.user == nil,
              url.password == nil else { return nil }
        if sameOrigin(url, baseURL) { return request }
        guard url.scheme?.caseInsensitiveCompare("https") == .orderedSame,
              request.httpMethod == "GET" || request.httpMethod == "HEAD",
              request.httpBody == nil,
              request.httpBodyStream == nil else {
            return nil
        }
        var request = request
        let allowedHeaders = Set(["accept", "accept-encoding", "accept-language", "range", "if-range", "user-agent"])
        for header in request.allHTTPHeaderFields?.keys.map({ $0 }) ?? []
        where !allowedHeaders.contains(header.lowercased()) {
            request.setValue(nil, forHTTPHeaderField: header)
        }
        return request
    }

}

private func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
    lhs.scheme?.caseInsensitiveCompare(rhs.scheme ?? "") == .orderedSame
        && lhs.host?.caseInsensitiveCompare(rhs.host ?? "") == .orderedSame
        && effectivePort(lhs) == effectivePort(rhs)
}

private func effectivePort(_ url: URL) -> Int? {
    if let port = url.port { return port }
    switch url.scheme?.lowercased() {
    case "https": return 443
    case "http": return 80
    default: return nil
    }
}

// MARK: - JSON coders

extension JSONEncoder {
    static let assinafy: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
}

extension JSONDecoder {
    static let assinafy: JSONDecoder = JSONDecoder()
}
