import Foundation

// MARK: - HTTPMethod

/// HTTP verbs used internally by the SDK.
@objc public enum HTTPMethod: Int {
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
public struct APIRequest {
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]?
    let body: Data?
    let contentType: String

    init(
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

    static func get(_ path: String, queryItems: [URLQueryItem]? = nil) -> APIRequest {
        APIRequest(method: .get, path: path, queryItems: queryItems)
    }

    static func delete(_ path: String) -> APIRequest {
        APIRequest(method: .delete, path: path)
    }

    static func post<B: Encodable>(_ path: String, body: B) throws -> APIRequest {
        let data = try JSONEncoder.assinafy.encode(body)
        return APIRequest(method: .post, path: path, body: data)
    }

    static func post(_ path: String) -> APIRequest {
        APIRequest(method: .post, path: path)
    }

    static func put<B: Encodable>(_ path: String, body: B) throws -> APIRequest {
        let data = try JSONEncoder.assinafy.encode(body)
        return APIRequest(method: .put, path: path, body: data)
    }

    static func put(_ path: String) -> APIRequest {
        APIRequest(method: .put, path: path)
    }

    static func put<B: Encodable>(_ path: String, body: B, queryItems: [URLQueryItem]) throws -> APIRequest {
        let data = try JSONEncoder.assinafy.encode(body)
        return APIRequest(method: .put, path: path, queryItems: queryItems, body: data)
    }

    static func patch<B: Encodable>(_ path: String, body: B) throws -> APIRequest {
        let data = try JSONEncoder.assinafy.encode(body)
        return APIRequest(method: .patch, path: path, body: data)
    }

    static func patch(_ path: String) -> APIRequest {
        APIRequest(method: .patch, path: path)
    }
}

// MARK: - APIResponse

/// Carries the raw body, headers, and status code of a successful HTTP response.
public struct APIResponse {
    /// Raw response body.
    public let data: Data
    /// All response headers, keyed by `AnyHashable`.
    public let headers: [AnyHashable: Any]
    /// HTTP status code (2xx when returned from the client).
    public let statusCode: Int
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
public final class URLSessionHTTPClient: HTTPClientProtocol {
    private let session: URLSession
    private let baseURL: URL
    private let defaultHeaders: [String: String]

    init(baseURL: URL, defaultHeaders: [String: String], timeout: TimeInterval = 30) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    public func perform(_ request: APIRequest) async throws -> APIResponse {
        let urlRequest = try buildURLRequest(from: request)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
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
            let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw APIError.from(statusCode: httpResponse.statusCode, responseData: parsed)
        }
        return APIResponse(
            data: data,
            headers: httpResponse.allHeaderFields,
            statusCode: httpResponse.statusCode
        )
    }

    private func buildURLRequest(from request: APIRequest) throws -> URLRequest {
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
