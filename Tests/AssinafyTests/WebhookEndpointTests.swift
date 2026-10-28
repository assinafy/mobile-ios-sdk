import XCTest
@testable import Assinafy

final class WebhookEndpointTests: XCTestCase {
    private var mock: MockHTTPClient!
    private var webhooks: WebhookResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        webhooks = WebhookResource(http: mock, defaultAccountId: "acc")
    }

    private let endpointJSON: [String: Any] = [
        "id": "ep1", "name": "ERP", "url": "https://example.invalid/hook",
        "email": "ops@example.invalid", "events": ["document_ready"],
        "is_active": true, "signing_enabled": true,
        "is_held": true, "held_since": 1_790_000_000,
        "created_at": "2026-10-01T12:00:00Z", "updated_at": "2026-10-01T12:00:00Z",
    ]

    private func body() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(mock.lastRequest?.body)) as? [String: Any])
    }

    func testListEndpointsDecodesEveryField() async throws {
        mock.stubEnvelopeList([endpointJSON])
        let endpoints = try await webhooks.listEndpoints()
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/webhooks/endpoints")
        let endpoint = try XCTUnwrap(endpoints.first)
        XCTAssertEqual(endpoint.id, "ep1")
        XCTAssertEqual(endpoint.name, "ERP")
        XCTAssertEqual(endpoint.events, ["document_ready"])
        XCTAssertTrue(endpoint.isActive)
        XCTAssertTrue(endpoint.signingEnabled)
        XCTAssertTrue(endpoint.isHeld)
        XCTAssertEqual(endpoint.heldSince?.intValue, 1_790_000_000)
        XCTAssertEqual(endpoint.createdAt, "2026-10-01T12:00:00Z")
    }

    func testCreateEndpointSendsDocumentedBody() async throws {
        var createdJSON = endpointJSON
        createdJSON["secret"] = "whsec_synthetic"
        mock.stubEnvelope(createdJSON)
        let endpoint = try await webhooks.createEndpoint(CreateWebhookEndpointPayload(
            url: "https://example.invalid/hook", email: "ops@example.invalid",
            events: ["document_ready"], name: "ERP", signingEnabled: true))
        XCTAssertEqual(endpoint.secret, "whsec_synthetic")
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/webhooks/endpoints")
        let json = try body()
        XCTAssertEqual(json["url"] as? String, "https://example.invalid/hook")
        XCTAssertEqual(json["email"] as? String, "ops@example.invalid")
        XCTAssertEqual(json["events"] as? [String], ["document_ready"])
        XCTAssertEqual(json["name"] as? String, "ERP")
        XCTAssertEqual(json["is_active"] as? Bool, true)
        XCTAssertEqual(json["signing_enabled"] as? Bool, true)
    }

    func testURLLookupKeepsOnlyExactMatchAndDeleteSendsURL() async throws {
        let url = "https://example.invalid/hook?tenant=a&key=b"
        var matching = endpointJSON
        matching["url"] = url
        mock.stubEnvelopeList([endpointJSON, matching])
        let matches = try await webhooks.listEndpoints(url: url, accountId: "override")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.url, url)
        XCTAssertNil(matches.first?.secret)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/override/webhooks/endpoints")
        XCTAssertEqual(mock.lastRequest?.queryItems, [URLQueryItem(name: "url", value: url)])
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)

        mock.stubEnvelopeList([])
        try await webhooks.deleteEndpoint(url: url)
        XCTAssertEqual(mock.lastRequest?.method, .delete)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/webhooks/endpoints")
        XCTAssertEqual(mock.lastRequest?.queryItems, [URLQueryItem(name: "url", value: url)])
        XCTAssertNil(mock.lastRequest?.body)
    }

    func testURLMethodsRejectInvalidURLBeforeIO() async {
        for url in ["", "file:///tmp/hook", "https://user:password@example.invalid/hook"] {
            do {
                _ = try await webhooks.listEndpoints(url: url)
                XCTFail("Expected ValidationError")
            } catch { XCTAssertTrue(error is ValidationError) }
            do {
                try await webhooks.deleteEndpoint(url: url)
                XCTFail("Expected ValidationError")
            } catch { XCTAssertTrue(error is ValidationError) }
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testCreateEndpointRejectsInvalidURLBeforeSending() async {
        do {
            _ = try await webhooks.createEndpoint(CreateWebhookEndpointPayload(
                url: "ftp://example.invalid", email: "ops@example.invalid"))
            XCTFail("Expected ValidationError")
        } catch {
            XCTAssertTrue(error is ValidationError)
        }
        XCTAssertNil(mock.lastRequest)
    }

    func testUpdateEndpointSendsOnlySetFields() async throws {
        var response = endpointJSON
        response["secret"] = "whsec_generated_by_update"
        mock.stubEnvelope(response)
        let updated = try await webhooks.updateEndpoint(id: "ep1", UpdateWebhookEndpointPayload(isActive: false, signingEnabled: true))
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/webhooks/endpoints/ep1")
        let json = try body()
        XCTAssertEqual(Set(json.keys), ["is_active", "signing_enabled"])
        XCTAssertEqual(json["is_active"] as? Bool, false)
        XCTAssertEqual(updated.secret, "whsec_generated_by_update")
    }

    func testUpdateEndpointRejectsEmptyPayload() async {
        do {
            _ = try await webhooks.updateEndpoint(id: "ep1", UpdateWebhookEndpointPayload())
            XCTFail("Expected ValidationError")
        } catch {
            XCTAssertTrue(error is ValidationError)
        }
    }

    func testGetAndDeleteEndpointRoutes() async throws {
        mock.stubEnvelope(endpointJSON)
        _ = try await webhooks.getEndpoint(id: "ep1")
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/webhooks/endpoints/ep1")

        mock.stubEnvelopeList([])
        try await webhooks.deleteEndpoint(id: "ep1")
        XCTAssertEqual(mock.lastRequest?.method, .delete)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/webhooks/endpoints/ep1")
    }

    func testSigningSecretRoutes() async throws {
        mock.stubEnvelope(["secret": "whsec_a"])
        let secret = try await webhooks.signingSecret(endpointId: "ep1")
        XCTAssertEqual(secret, "whsec_a")
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/webhooks/endpoints/ep1/secret")

        mock.stubEnvelope(["secret": "whsec_b"])
        let rotated = try await webhooks.rotateSigningSecret(endpointId: "ep1")
        XCTAssertEqual(rotated, "whsec_b")
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/webhooks/endpoints/ep1/secret/rotate")
    }

    func testEndpointRoutesRejectBlankEndpointId() async {
        do {
            _ = try await webhooks.getEndpoint(id: " ")
            XCTFail("Expected ValidationError")
        } catch {
            XCTAssertTrue(error is ValidationError)
        }
    }

    func testEndpointHoldMetadataAllowsNullAndLegacyResponses() throws {
        var response = endpointJSON
        response["is_held"] = false
        response["held_since"] = NSNull()
        let running = try JSONDecoder.assinafy.decode(
            WebhookEndpoint.self, from: JSONSerialization.data(withJSONObject: response))
        XCTAssertFalse(running.isHeld)
        XCTAssertNil(running.heldSince)

        response.removeValue(forKey: "is_held")
        response.removeValue(forKey: "held_since")
        let legacy = try JSONDecoder.assinafy.decode(
            WebhookEndpoint.self, from: JSONSerialization.data(withJSONObject: response))
        XCTAssertFalse(legacy.isHeld)
        XCTAssertNil(legacy.heldSince)
    }

    func testDispatchCarriesEndpointIdAndFilterSendsIt() async throws {
        mock.stubEnvelopeList([[
            "id": "d1", "event": "document_ready", "activity_id": 1,
            "endpoint_id": "ep1", "delivered": true,
        ]])
        let params = WebhookDispatchListParams()
        params.endpointId = "ep1"
        let result = try await webhooks.listDispatches(params: params)
        XCTAssertEqual(result.data.first?.endpointId, "ep1")
        XCTAssertEqual(mock.lastRequest?.queryItems, [URLQueryItem(name: "endpoint_id", value: "ep1")])
    }

    func testEndpointCompletionDeliversOnMainQueue() {
        mock.stubEnvelope(["secret": "whsec_a"])
        let done = expectation(description: "completion")
        webhooks.signingSecret(endpointId: "ep1", accountId: nil) { secret, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(secret, "whsec_a")
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
    }
}

/// Vector computed independently with Python's `hmac` over
/// `msg_1.1790000000.{body}` and the key in ``secret``.
final class WebhookSignatureTests: XCTestCase {
    private let secret = "whsec_dGVzdC1zaWduaW5nLWtleS0wMTIzNDU2Nzg5YWJjZGVm"
    private let signature = "v1,Xr7EGoZ3IgpN2Qum5O4pLVbXLS0jCFgD5ZpRsvEzp2E="
    private let body = Data(#"{"event":"document_ready","account_id":"acc"}"#.utf8)
    private let now = Date(timeIntervalSince1970: 1_790_000_010)

    private func verify(body: Data? = nil, id: String = "msg_1", timestamp: String = "1790000000",
                        header: String? = nil, secret: String? = nil, now: Date? = nil) -> Bool {
        WebhookSignature.verify(body: body ?? self.body, id: id, timestamp: timestamp,
                                signatureHeader: header ?? signature, secret: secret ?? self.secret,
                                tolerance: WebhookSignature.defaultTolerance, now: now ?? self.now)
    }

    func testAcceptsValidSignature() {
        XCTAssertTrue(verify())
    }

    func testAcceptsAnyMatchingEntryAmongSeveral() {
        XCTAssertTrue(verify(header: "v1,AAAA \(signature)"))
    }

    func testRejectsAlteredBodyIdOrSecret() {
        XCTAssertFalse(verify(body: Data(#"{"event":"document_ready"}"#.utf8)))
        XCTAssertFalse(verify(id: "msg_2"))
        XCTAssertFalse(verify(secret: "whsec_" + Data("other-key".utf8).base64EncodedString()))
    }

    func testRejectsStaleTimestampAndMalformedInput() {
        XCTAssertFalse(verify(now: Date(timeIntervalSince1970: 1_790_000_000 + 301)))
        XCTAssertFalse(verify(timestamp: "not-a-number"))
        XCTAssertFalse(verify(header: "v2,\(signature.dropFirst(3))"))
        XCTAssertFalse(verify(secret: String(secret.dropFirst("whsec_".count))))
        XCTAssertFalse(verify(header: ""))
    }
}
