import XCTest
@testable import Assinafy

final class NotificationAndEmbedTests: XCTestCase {
    func testWorkspacePolicyAndEmbedRoutes() async throws {
        let mock = MockHTTPClient()
        let workspace = WorkspaceResource(http: mock, defaultAccountId: "a")
        func check(_ method: HTTPMethod, _ suffix: String) {
            XCTAssertEqual(mock.lastRequest?.method, method)
            XCTAssertEqual(mock.lastRequest?.path, "/accounts/a/" + suffix)
            XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        }
        let policy: [String: Any] = ["editable": true, "owners_receive_all": false, "events": ["SignerSigned": false]]
        mock.stubEnvelope(policy)
        let result = try await workspace.notificationPolicy()
        check(.get, "notification-policy")
        XCTAssertEqual(result.events["SignerSigned"], false)
        mock.stubEnvelope(policy)
        _ = try await workspace.updateNotificationPolicy(payload: .init(events: ["SignerSigned": false], ownersReceiveAll: false))
        check(.put, "notification-policy")
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(mock.lastRequest?.body)) as? [String: Any]
        XCTAssertEqual(body?["owners_receive_all"] as? Bool, false)
        XCTAssertThrowsError(try JSONEncoder.assinafy.encode(UpdateNotificationPolicyPayload()))
        let origin: [String: Any] = ["id": "o", "origin": "https://app.example.invalid", "created_at": "2026-11-11"]
        mock.stubEnvelopeList([origin])
        let origins = try await workspace.listEmbedOrigins()
        check(.get, "embed-origins")
        XCTAssertEqual(origins.first?.id, "o")
        mock.stubEnvelope(origin)
        _ = try await workspace.addEmbedOrigin(origin: "https://app.example.invalid")
        check(.post, "embed-origins")
        mock.stubEnvelope(origin)
        _ = try await workspace.updateEmbedOrigin(originId: "o", origin: "https://app.example.invalid")
        check(.put, "embed-origins/o")
        mock.stubEnvelopeList([])
        try await workspace.deleteEmbedOrigin(originId: "o")
        check(.delete, "embed-origins/o")
        mock.stubEnvelope(["id": "a", "name": "Workspace", "created_at": "2026-11-11", "signing_features": ["Embed": true]])
        let account = try await workspace.get(workspaceId: "a", expand: ["signing_features"])
        XCTAssertEqual(account.signingFeatures?["Embed"], true)
        XCTAssertEqual(mock.lastRequest?.queryItems, [URLQueryItem(name: "expand", value: "signing_features")])
        mock.stubEnvelope(["url": "https://app.example.invalid/embed/secret", "expires_at": "2026-11-11T12:05:00Z"])
        let session = try await AssignmentResource(http: mock).createEmbedSession(documentId: "d", assignmentId: "as", signerId: "s")
        XCTAssertEqual(session.expiresAt, "2026-11-11T12:05:00Z")
        XCTAssertEqual(mock.lastRequest?.path, "/documents/d/assignments/as/signers/s/embed-sessions")
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
    }

    func testUsageRetainsExactAndUnlimitedBalances() async throws {
        let mock = MockHTTPClient()
        mock.stub(response: APIResponse(data: Data(#"{"status":200,"data":{"plan":null,"documents_renewal_date":null,"balances":{"credits":{"balance":12.34,"limit":null,"spent":0.01}}}}"#.utf8), statusCode: 200))
        let usage = try await WorkspaceResource(http: mock, defaultAccountId: "a").usage()
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/a/usage")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        XCTAssertNil(usage.plan)
        XCTAssertNil(usage.balances["credits"]?.limit)
        XCTAssertEqual(usage.balances["credits"]?.balance, NSDecimalNumber(string: "12.34"))
        XCTAssertEqual(usage.balances["credits"]?.spent, NSDecimalNumber(string: "0.01"))
    }

    func testPushPreferencesAndMainQueueDelivery() async throws {
        let mock = MockHTTPClient()
        let auth = AuthResource(http: mock)
        mock.stubEnvelope(["SignerSigned": false, "FutureEvent": true])
        let preferences = try await auth.getPushPreferences()
        XCTAssertEqual(preferences["FutureEvent"], true)
        XCTAssertEqual(mock.lastRequest?.path, "/users/self/push-preferences")
        mock.stubEnvelope(["SignerSigned": false])
        let done = expectation(description: "push completion")
        auth.updatePushPreferences(preferences: ["SignerSigned": false]) { value, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(value?["SignerSigned"], false)
            XCTAssertNil(error)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 5)
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        let count = mock.allRequests.count
        do { _ = try await auth.updatePushPreferences(preferences: [:]); XCTFail() }
        catch { XCTAssertTrue(error is ValidationError) }
        XCTAssertEqual(mock.allRequests.count, count)
    }
}
