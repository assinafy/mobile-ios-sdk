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
            "resource": "account",
            "id": id,
            "name": name,
            "primary_color": "aabbcc",
            "secondary_color": "112233",
            "notification_sender_type": "Account",
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
        _ = try await resource.create(
            CreateWorkspacePayload(name: "Acme Corp", notificationSenderType: NotificationSenderType.account)
        )
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No request body")
            return
        }
        XCTAssertEqual(json["name"] as? String, "Acme Corp")
        XCTAssertEqual(json["notification_sender_type"] as? String, "Account")
    }

    func testSandboxCreateOmitsUnsupportedNotificationSenderType() async throws {
        let sandboxResource = WorkspaceResource(
            http: mock,
            defaultAccountId: "test-account",
            usesSandboxCompatibility: true
        )
        mock.stubEnvelope(workspaceDict())

        _ = try await sandboxResource.create(
            CreateWorkspacePayload(
                name: "Acme Corp",
                notificationSenderType: NotificationSenderType.account
            )
        )

        let body = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "Acme Corp")
        XCTAssertNil(json["notification_sender_type"])
    }

    func testDeleteSendsForceBody() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 204))
        try await resource.delete(workspaceId: "ws1", force: true)
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No request body")
            return
        }
        XCTAssertEqual(json["force"] as? Bool, true)
    }

    func testThemeUsesCorrectPath() async throws {
        mock.stubEnvelope(["account_name": "MT", "primary_color": "2072b9", "secondary_color": "ffffff"])
        let theme = try await resource.theme()
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/theme")
        XCTAssertEqual(theme.primaryColor, "2072b9")
    }

    func testListUsesAccountsEndpoint() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.list(params: ListParams(
            page: 999,
            perPage: 1,
            search: "ignored",
            sort: "-created_at"
        ))
        XCTAssertEqual(mock.lastRequest?.path, "/accounts")
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertNil(mock.lastRequest?.queryItems)
    }

    func testListDecodesCompleteAccountFields() async throws {
        mock.stubEnvelopeList([workspaceDict()])
        let result = try await resource.list()
        let workspace = try XCTUnwrap(result.data.first)
        XCTAssertEqual(workspace.resource, "account")
        XCTAssertEqual(workspace.primaryColor, "aabbcc")
        XCTAssertEqual(workspace.secondaryColor, "112233")
        XCTAssertEqual(workspace.notificationSenderType, "Account")
        XCTAssertEqual(workspace.roles, ["owner"])
        XCTAssertTrue(workspace.isDeleteAllowed)
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
        let workspace = try await resource.get(workspaceId: "ws1")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/ws1")
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(workspace.resource, "account")
        XCTAssertEqual(workspace.primaryColor, "aabbcc")
        XCTAssertEqual(workspace.secondaryColor, "112233")
        XCTAssertEqual(workspace.notificationSenderType, "Account")
        XCTAssertEqual(workspace.roles, ["owner"])
        XCTAssertTrue(workspace.isDeleteAllowed)
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
