import XCTest
@testable import Assinafy

final class MockHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    private enum Stub {
        case response(APIResponse)
        case error(Error)
    }

    private var stubs: [Stub] = []
    private(set) var lastRequest: APIRequest?
    private(set) var allRequests: [APIRequest] = []

    func stub(response: APIResponse) {
        stubs.append(.response(response))
    }

    func stub(error: Error) {
        stubs.append(.error(error))
    }

    func stubJSON(_ json: [String: Any], headers: [AnyHashable: Any] = [:]) {
        let data = try! JSONSerialization.data(withJSONObject: json)
        stub(response: APIResponse(data: data, headers: headers, statusCode: 200))
    }

    func stubEnvelope(_ value: [String: Any], headers: [AnyHashable: Any] = [:]) {
        stubJSON(["status": 200, "message": "", "data": value], headers: headers)
    }

    func stubEnvelopeList(_ items: [[String: Any]], headers: [AnyHashable: Any] = [:]) {
        stubJSON(["status": 200, "message": "", "data": items], headers: headers)
    }

    func perform(_ request: APIRequest) async throws -> APIResponse {
        lastRequest = request
        allRequests.append(request)

        guard !stubs.isEmpty else {
            throw AssinafySDKError("MockHTTPClient received an unstubbed request: \(request.method.httpValue) \(request.path)")
        }
        switch stubs.removeFirst() {
        case .response(let response):
            return response
        case .error(let error):
            throw error
        }
    }

    static func paginationHeaders(currentPage: Int, perPage: Int, total: Int, pageCount: Int) -> [AnyHashable: Any] {
        [
            "X-Pagination-Current-Page": "\(currentPage)",
            "X-Pagination-Per-Page": "\(perPage)",
            "X-Pagination-Total-Count": "\(total)",
            "X-Pagination-Page-Count": "\(pageCount)"
        ]
    }
}
