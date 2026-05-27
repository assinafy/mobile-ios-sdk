import XCTest
@testable import Assinafy

final class TagResourceTests: XCTestCase {
    var mock: MockHTTPClient!
    var resource: TagResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        resource = TagResource(http: mock, defaultAccountId: "acc1")
    }

    private func tagDict(id: String = "tag1", name: String = "Contracts", color: Any? = "ff8800") -> [String: Any] {
        [
            "id": id,
            "name": name,
            "color": color ?? NSNull(),
            "created_at": "2026-05-14T12:00:00Z",
            "updated_at": "2026-05-14T12:00:00Z",
        ]
    }

    func testListUsesTagsEndpointAndSearchFilter() async throws {
        mock.stubEnvelopeList([tagDict()])
        _ = try await resource.list(params: TagListParams(search: "contract"))
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/tags")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first, URLQueryItem(name: "search", value: "contract"))
    }

    func testCreatePostsTagPayload() async throws {
        mock.stubEnvelope(tagDict())
        _ = try await resource.create(CreateTagPayload(name: "Contracts", color: "ff8800"))
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/tags")
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["name"] as? String, "Contracts")
        XCTAssertEqual(json["color"] as? String, "ff8800")
    }

    func testUpdateCanClearColor() async throws {
        mock.stubEnvelope(tagDict(color: nil))
        _ = try await resource.update(tagId: "tag1", payload: UpdateTagPayload(clearsColor: true))
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/tags/tag1")
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertTrue(json["color"] is NSNull)
    }

    func testDeleteSupportsForceQuery() async throws {
        mock.stubEnvelope(["deleted": true])
        try await resource.delete(tagId: "tag1", force: true)
        XCTAssertEqual(mock.lastRequest?.method, .delete)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/tags/tag1")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first, URLQueryItem(name: "force", value: "true"))
    }

    func testListDocumentTagsUsesDocumentEndpoint() async throws {
        mock.stubEnvelopeList([tagDict()])
        let tags = try await resource.listDocumentTags(documentId: "doc1")
        XCTAssertEqual(tags.first?.id, "tag1")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/documents/doc1/tags")
    }

    func testReplaceDocumentTagsAllowsEmptyArray() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.replaceDocumentTags(documentId: "doc1", tagNames: [])
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/documents/doc1/tags")
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["tags"] as? [String], [])
    }

    func testAppendDocumentTagsRequiresAtLeastOneName() async {
        await assertThrowsValidationError {
            _ = try await self.resource.appendDocumentTags(documentId: "doc1", tagNames: [])
        }
    }

    func testAppendDocumentTagsPostsNames() async throws {
        mock.stubEnvelopeList([tagDict()])
        _ = try await resource.appendDocumentTags(documentId: "doc1", tagNames: ["Contracts"])
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/documents/doc1/tags")
    }

    func testDetachDocumentTagUsesDeleteEndpoint() async throws {
        mock.stubEnvelope(["detached": true])
        try await resource.detachDocumentTag(documentId: "doc1", tagId: "tag1")
        XCTAssertEqual(mock.lastRequest?.method, .delete)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/documents/doc1/tags/tag1")
    }
}
