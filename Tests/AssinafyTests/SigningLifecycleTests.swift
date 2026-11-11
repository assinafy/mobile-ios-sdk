import XCTest
@testable import Assinafy

final class SigningLifecycleTests: XCTestCase {
    func testSignerEnvelopeNavigationPreservesCredentialScope() async throws {
        let mock = MockHTTPClient()
        let resource = SignerResource(http: mock)
        let summary: [String: Any] = ["id": "d", "name": "Document", "status": "certificated", "is_signer_access_closed": true]
        mock.stubEnvelope(summary)
        _ = try await resource.getSigningDocument(signerAccessCode: "code", expand: ["envelope"], documentId: "d")
        XCTAssertEqual(mock.lastRequest?.credential, .withheld)
        XCTAssertEqual(mock.lastRequest?.queryItems, [
            URLQueryItem(name: "signer-access-code", value: "code"),
            URLQueryItem(name: "expand", value: "envelope"),
            URLQueryItem(name: "document_id", value: "d")
        ])
        mock.stubEnvelope(summary)
        let done = expectation(description: "expanded signer completion")
        resource.getCurrentDocument(signerId: "s", signerAccessCode: "code", expand: ["envelope"]) { document, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(document?.id, "d")
            XCTAssertNil(error)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 5)
        XCTAssertEqual(mock.lastRequest?.credential, .withheld)
        XCTAssertEqual(mock.lastRequest?.path, "/signers/s/document")
        XCTAssertEqual(mock.lastRequest?.queryItems?.last, URLQueryItem(name: "expand", value: "envelope"))
        let count = mock.allRequests.count
        do { _ = try await resource.getSigningDocument(signerAccessCode: "code", expand: [], documentId: ""); XCTFail() }
        catch { XCTAssertTrue(error is ValidationError) }
        XCTAssertEqual(mock.allRequests.count, count)
    }

    func testNullSigningLinksAndClosedAccessSummaryDecode() throws {
        for embedded in [false, true] {
            let data = try JSONSerialization.data(withJSONObject: ["signer_id": "s", "url": NSNull(), "embedded": embedded])
            let link = try JSONDecoder.assinafy.decode(AssignmentSigningURL.self, from: data)
            XCTAssertNil(link.signingURL)
            XCTAssertEqual(link.url, "")
            XCTAssertEqual(link.embedded, embedded)
        }
        let data = Data(#"{"id":"d","name":"Agreement","status":"certificated","is_signer_access_closed":true,"certified_copy":{"available":true,"notification_method":"Email","resends_left":null},"envelope":{"id":"e","name":"Pack"}}"#.utf8)
        let document = try JSONDecoder.assinafy.decode(DocumentDetails.self, from: data)
        XCTAssertTrue(document.isSignerAccessClosed)
        XCTAssertEqual(document.createdAt, "")
        XCTAssertTrue(document.certifiedCopy?.available == true)
        XCTAssertEqual(document.envelope?.id, "e")
    }

    func testAssignmentEmbeddingAndCeilingSurviveJSONBridge() throws {
        let data = Data(#"{"method":"virtual","signers":[{"id":"s","embedded":true}],"max_total_credits":0.45}"#.utf8)
        let payload = try CreateAssignmentPayload(jsonData: data)
        let body = try buildAssignmentBody(payload)
        XCTAssertEqual(body.signers.first?.embedded, true)
        XCTAssertEqual(body.maxTotalCredits, Decimal(string: "0.45"))
        let decoded = try CreateAssignmentPayload(jsonData: JSONEncoder.assinafy.encode(body))
        XCTAssertEqual(decoded.embeddedSignerIds, ["s"])
        var invalid = payload
        invalid.embeddedSignerIds = ["other"]
        XCTAssertThrowsError(try buildAssignmentBody(invalid))
        invalid = payload
        invalid.maxTotalCredits = -1
        XCTAssertThrowsError(try buildAssignmentBody(invalid))
    }

    func testIdempotencyHeaderIsValidatedAndPreservedByCredentialWithholding() throws {
        let transport = URLSessionHTTPClient(baseURL: URL(string: "https://example.invalid/v1")!)
        let request = try APIRequest.post("/envelopes").withIdempotencyKey("same-key").withoutWorkspaceCredential()
        XCTAssertEqual(try transport.buildURLRequest(from: request).value(forHTTPHeaderField: "Idempotency-Key"), "same-key")
        XCTAssertThrowsError(try request.withIdempotencyKey("injected\r\nHeader: value"))
        XCTAssertThrowsError(try request.withIdempotencyKey(" "))
    }

    func testTemplateCeilingEmbeddingAndIdempotencyReachRequest() async throws {
        let mock = MockHTTPClient()
        mock.stubEnvelope(["id": "d", "name": "d", "status": "uploaded", "artifacts": ["original": "https://example.invalid/file"], "created_at": "now", "updated_at": "now"])
        let options = CreateDocumentFromTemplateOptions()
        options.idempotencyKey = "key"
        options.maxTotalCredits = NSDecimalNumber(string: "0.45")
        let signer = TemplateSigner(roleId: "r", id: "s")
        signer.embedded = true
        _ = try await DocumentResource(http: mock, defaultAccountId: "a").createFromTemplate(templateId: "t", signers: [signer], options: options)
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(mock.lastRequest?.body)) as? [String: Any]
        XCTAssertEqual(body?["max_total_credits"] as? Double, 0.45)
        XCTAssertEqual((body?["signers"] as? [[String: Any]])?.first?["embedded"] as? Bool, true)
        XCTAssertEqual(mock.lastRequest?.idempotencyKey, "key")
    }
}
