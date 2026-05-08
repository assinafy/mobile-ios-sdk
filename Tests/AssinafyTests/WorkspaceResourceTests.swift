import XCTest
@testable import Assinafy

final class WorkspaceResourceTests: XCTestCase {
    var mock: MockHTTPClient!
    var resource: WorkspaceResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        resource = WorkspaceResource(http: mock, defaultAccountId: "test-account")
    }

    private func workspaceDict(id: String = "ws1", name: String = "Test Workspace") -> [String: Any] {
        [
            "id": id,
            "name": name,
            "created_at": "2024-01-01",
            "is_delete_allowed": true,
            "roles": ["owner"],
        ]
    }

    func testCreatePostsToAccountsEndpoint() async throws {
        mock.stubEnvelope(workspaceDict())
        _ = try await resource.create(CreateWorkspacePayload(name: "Test Workspace"))
        XCTAssertEqual(mock.lastRequest?.path, "/accounts")
        XCTAssertEqual(mock.lastRequest?.method, .post)
    }

    func testCreateEncodesPayloadFields() async throws {
        mock.stubEnvelope(workspaceDict())
        _ = try await resource.create(CreateWorkspacePayload(name: "Acme Corp", primaryColor: "#FF0000"))
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No request body")
            return
        }
        XCTAssertEqual(json["name"] as? String, "Acme Corp")
        XCTAssertEqual(json["primary_color"] as? String, "#FF0000")
    }

    func testListUsesAccountsEndpoint() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.list()
        XCTAssertEqual(mock.lastRequest?.path, "/accounts")
        XCTAssertEqual(mock.lastRequest?.method, .get)
    }

    func testListReturnsPaginationMeta() async throws {
        let headers = MockHTTPClient.paginationHeaders(currentPage: 1, perPage: 10, total: 5, pageCount: 1)
        mock.stubEnvelopeList([], headers: headers)
        let result = try await resource.list()
        XCTAssertEqual(result.meta?.currentPage, 1)
        XCTAssertEqual(result.meta?.total, 5)
    }

    func testGetUsesCorrectPath() async throws {
        mock.stubEnvelope(workspaceDict())
        _ = try await resource.get(workspaceId: "ws1")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/ws1")
        XCTAssertEqual(mock.lastRequest?.method, .get)
    }

    func testGetThrowsForEmptyWorkspaceID() async {
        await assertThrowsValidationError {
            _ = try await self.resource.get(workspaceId: "")
        }
    }

    func testUpdateUsesCorrectPath() async throws {
        mock.stubEnvelope(workspaceDict(name: "New Name"))
        _ = try await resource.update(workspaceId: "ws1", payload: UpdateWorkspacePayload(name: "New Name"))
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/ws1")
        XCTAssertEqual(mock.lastRequest?.method, .put)
    }

    func testUpdateThrowsForEmptyWorkspaceID() async {
        await assertThrowsValidationError {
            _ = try await self.resource.update(workspaceId: "", payload: UpdateWorkspacePayload())
        }
    }

    func testDeleteUsesCorrectPath() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 204))
        try await resource.delete(workspaceId: "ws1")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/ws1")
        XCTAssertEqual(mock.lastRequest?.method, .delete)
    }

    func testDeleteThrowsForEmptyWorkspaceID() async {
        await assertThrowsValidationError {
            try await self.resource.delete(workspaceId: "")
        }
    }
}
