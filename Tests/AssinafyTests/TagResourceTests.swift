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
            "resource": "tag",
            "id": id,
            "name": name,
            "color": color ?? NSNull(),
            "created_at": "2026-05-14T12:00:00Z",
            "updated_at": "2026-05-14T12:00:00Z",
        ]
    }

    func testListUsesTagsEndpointAndSearchFilter() async throws {
        mock.stubEnvelopeList([tagDict()])
        let result = try await resource.list(params: TagListParams(search: "contract"))
        XCTAssertEqual(result.data.first?.resource, "tag")
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

    func testCreateRejectsInvalidColorBeforeRequest() async {
        await assertThrowsValidationError {
            _ = try await self.resource.create(
                CreateTagPayload(name: "Contracts", color: "orange")
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
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

    func testUpdateRejectsEmptyPayloadBeforeRequest() async {
        await assertThrowsValidationError {
            _ = try await self.resource.update(
                tagId: "tag1",
                payload: UpdateTagPayload()
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testDeleteSupportsForceQuery() async throws {
        mock.stubEnvelope(["deleted": true])
        try await resource.delete(tagId: "tag1", force: true)
        XCTAssertEqual(mock.lastRequest?.method, .delete)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/tags/tag1")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first, URLQueryItem(name: "force", value: "true"))
    }

    func testDeleteCanReturnDocumentedStatus() async throws {
        mock.stubEnvelope(["deleted": true])
        let deleted = try await resource.deleteAndReturnStatus(tagId: "tag1")
        XCTAssertTrue(deleted)
    }

    func testListDocumentTagsUsesDocumentEndpoint() async throws {
        mock.stubEnvelopeList([tagDict()])
        let tags = try await resource.listDocumentTags(documentId: "doc1")
        XCTAssertEqual(tags.first?.id, "tag1")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/documents/doc1/tags")
    }

    func testReplaceDocumentTagsAllowsEmptyArray() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.replaceDocumentTags(documentId: "doc1", tagIds: [])
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
            _ = try await self.resource.appendDocumentTags(documentId: "doc1", tagIds: [])
        }
    }

    func testAppendDocumentTagsPostsIDs() async throws {
        mock.stubEnvelopeList([tagDict()])
        _ = try await resource.appendDocumentTags(documentId: "doc1", tagIds: ["tag1"])
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/documents/doc1/tags")
        let body = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["tags"] as? [String], ["tag1"])
    }

    func testSandboxDocumentTagMutationMapsIDsToNames() async throws {
        let sandboxResource = TagResource(
            http: mock,
            defaultAccountId: "acc1",
            usesSandboxCompatibility: true
        )
        mock.stubEnvelopeList([tagDict(id: "tag1", name: "Contracts")])
        mock.stubEnvelopeList([])
        mock.stubEnvelopeList([tagDict(id: "tag1", name: "Contracts")])

        let tags = try await sandboxResource.appendDocumentTags(
            documentId: "doc1",
            tagIds: ["tag1"]
        )

        XCTAssertEqual(mock.allRequests.map(\.path), [
            "/accounts/acc1/tags",
            "/accounts/acc1/documents/doc1/tags",
            "/accounts/acc1/documents/doc1/tags",
        ])
        XCTAssertEqual(
            mock.allRequests.first?.queryItems,
            [
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "per-page", value: "100"),
            ]
        )
        XCTAssertEqual(tags.first?.id, "tag1")
        let body = try XCTUnwrap(mock.allRequests[1].body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["tags"] as? [String], ["Contracts"])
    }

    func testSandboxDocumentTagMutationRejectsUnknownIDBeforeMutation() async {
        let sandboxResource = TagResource(
            http: mock,
            defaultAccountId: "acc1",
            usesSandboxCompatibility: true
        )
        mock.stubEnvelopeList([tagDict(id: "tag1", name: "Contracts")])

        await assertThrowsValidationError {
            _ = try await sandboxResource.appendDocumentTags(
                documentId: "doc1",
                tagIds: ["missing-tag"]
            )
        }

        XCTAssertEqual(mock.allRequests.count, 1)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/tags")
    }

    func testSandboxTagResolutionTraversesPagination() async throws {
        let sandboxResource = TagResource(
            http: mock,
            defaultAccountId: "acc1",
            usesSandboxCompatibility: true
        )
        let firstPage = (0..<100).map {
            tagDict(id: "tag-\($0)", name: "Tag \($0)")
        }
        mock.stubEnvelopeList(
            firstPage,
            headers: MockHTTPClient.paginationHeaders(
                currentPage: 1,
                perPage: 100,
                total: 101,
                pageCount: 2
            )
        )
        mock.stubEnvelopeList(
            [tagDict(id: "target-tag", name: "Target")],
            headers: MockHTTPClient.paginationHeaders(
                currentPage: 2,
                perPage: 100,
                total: 101,
                pageCount: 2
            )
        )
        mock.stubEnvelopeList([tagDict(id: "target-tag", name: "Target")])

        _ = try await sandboxResource.appendDocumentTags(
            documentId: "doc1",
            tagIds: ["target-tag"]
        )

        XCTAssertEqual(
            mock.allRequests[1].queryItems?.first,
            URLQueryItem(name: "page", value: "2")
        )
        let body = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["tags"] as? [String], ["Target"])
    }

    func testDetachDocumentTagUsesDeleteEndpoint() async throws {
        mock.stubEnvelope(["detached": true])
        try await resource.detachDocumentTag(documentId: "doc1", tagId: "tag1")
        XCTAssertEqual(mock.lastRequest?.method, .delete)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/documents/doc1/tags/tag1")
    }

    func testDetachDocumentTagCanReturnDocumentedStatus() async throws {
        mock.stubEnvelope(["detached": true])
        let detached = try await resource.detachDocumentTagAndReturnStatus(
            documentId: "doc1",
            tagId: "tag1"
        )
        XCTAssertTrue(detached)
    }
}
