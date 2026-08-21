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
        StubURLProtocol.state.set { _ in throw URLError(.timedOut) }

        do {
            _ = try await transport().perform(.get("/timeout"))
            XCTFail("Expected NetworkError")
        } catch let error as NetworkError {
            XCTAssertNotNil(error.underlyingError)
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }
}
