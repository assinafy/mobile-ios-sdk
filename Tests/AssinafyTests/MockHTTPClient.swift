import XCTest
@testable import Assinafy

final class MockHTTPClient: HTTPClientProtocol {
    private var responseStub: APIResponse?
    private var errorStub: Error?
    private(set) var lastRequest: APIRequest?
    private(set) var allRequests: [APIRequest] = []

    func stub(response: APIResponse) {
        self.responseStub = response
        self.errorStub = nil
    }

    func stub(error: Error) {
        self.errorStub = error
        self.responseStub = nil
    }

    func stubJSON(_ json: [String: Any], headers: [AnyHashable: Any] = [:]) {
        let data = try! JSONSerialization.data(withJSONObject: json)
        self.responseStub = APIResponse(data: data, headers: headers, statusCode: 200)
        self.errorStub = nil
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

        if let error = errorStub {
            throw error
        }

        if let response = responseStub {
            return response
        }

        return APIResponse(data: Data(), headers: [:], statusCode: 200)
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
