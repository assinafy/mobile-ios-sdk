import XCTest
@testable import Assinafy

final class DocumentResourceTests: XCTestCase {
    var mock: MockHTTPClient!
    var resource: DocumentResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        resource = DocumentResource(http: mock, defaultAccountId: "test-account")
    }

    private func uploadResponseDict(id: String = "doc1") -> [String: Any] {
        [
            "id": id,
            "account_id": "test-account",
            "name": "document.pdf",
            "status": "uploaded",
            "artifacts": ["original": "https://api.assinafy.com.br/v1/documents/\(id)/download/original"],
            "pages": [],
            "created_at": "2024-01-01",
            "updated_at": "2024-01-01",
            "is_closed": false,
        ]
    }

    private func documentDetailsDict(id: String = "doc1") -> [String: Any] {
        [
            "id": id,
            "account_id": "acc1",
            "name": "test.pdf",
            "status": "pending_signature",
            "pages": [],
            "created_at": "2024-01-01",
            "updated_at": "2024-01-01",
        ]
    }

    // MARK: - Upload validation

    func testUploadRejectsEmptyData() async {
        await assertThrowsValidationError {
            _ = try await self.resource.upload(Data())
        }
    }

    func testUploadRejectsNonPDFData() async {
        await assertThrowsValidationError {
            _ = try await self.resource.upload(Data([0x00, 0x01, 0x02, 0x03]))
        }
    }

    func testUploadRejectsFilesOver25MB() async {
        let big = Data(repeating: 0, count: 26 * 1024 * 1024)
        await assertThrowsValidationError {
            _ = try await self.resource.upload(big)
        }
    }

    func testUploadUsesMultipartPostToDocumentsEndpoint() async throws {
        mock.stubEnvelope(uploadResponseDict())
        let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
        _ = try await resource.upload(pdf)
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/documents")
        XCTAssertTrue(mock.lastRequest?.contentType.hasPrefix("multipart/form-data; boundary=") == true)
    }

    // MARK: - List

    func testListReturnsPaginationMeta() async throws {
        let headers = MockHTTPClient.paginationHeaders(currentPage: 1, perPage: 10, total: 25, pageCount: 3)
        mock.stubEnvelopeList([], headers: headers)
        let result = try await resource.list()
        XCTAssertEqual(result.meta?.currentPage, 1)
        XCTAssertEqual(result.meta?.perPage, 10)
        XCTAssertEqual(result.meta?.total, 25)
        XCTAssertEqual(result.meta?.lastPage, 3)
    }

    // MARK: - Get

    func testGetUsesCorrectPath() async throws {
        mock.stubEnvelope(documentDetailsDict())
        _ = try await resource.get(documentId: "doc1")
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1")
        XCTAssertEqual(mock.lastRequest?.method, .get)
    }

    func testGetThrowsForEmptyDocumentID() async {
        await assertThrowsValidationError {
            _ = try await self.resource.get(documentId: "")
        }
    }

    // MARK: - Delete

    func testDeleteUsesCorrectPath() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 204))
        try await resource.delete(documentId: "doc1")
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1")
        XCTAssertEqual(mock.lastRequest?.method, .delete)
    }

    func testDeleteThrowsForEmptyDocumentID() async {
        await assertThrowsValidationError {
            try await self.resource.delete(documentId: "")
        }
    }

    // MARK: - Download

    func testDownloadArtifactSendsGetRequest() async throws {
        mock.stub(response: APIResponse(data: Data([0x25, 0x50, 0x44, 0x46]), headers: [:], statusCode: 200))
        _ = try await resource.downloadArtifact(documentId: "doc1", artifact: .original)
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1/download/original")
    }

    func testDownloadPageRejectsEmptyPageID() async {
        await assertThrowsValidationError {
            _ = try await self.resource.downloadPage(documentId: "doc1", pageId: "")
        }
    }

    func testDownloadPageUsesDocumentedDownloadPath() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        _ = try await resource.downloadPage(documentId: "doc1", pageId: "page1")
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1/pages/page1/download")
    }

    // MARK: - Verify

    func testVerifyUsesSignatureHashEndpoint() async throws {
        mock.stubEnvelope(["is_valid": true])
        _ = try await resource.verify(signatureHash: "hash-1")
        XCTAssertEqual(mock.lastRequest?.path, "/documents/hash-1/verify")
        XCTAssertEqual(mock.lastRequest?.method, .get)
    }

    // MARK: - Signing progress

    func testGetSigningProgressReturnsZeroWhenNoAssignment() async throws {
        mock.stubEnvelope(documentDetailsDict())
        let progress = try await resource.getSigningProgress(documentId: "doc1")
        XCTAssertEqual(progress.signed, 0)
        XCTAssertEqual(progress.total, 0)
        XCTAssertEqual(progress.pending, 0)
        XCTAssertEqual(progress.percentage, 0)
    }

    func testIsFullySignedReturnsFalseWhenNoAssignment() async throws {
        mock.stubEnvelope(documentDetailsDict())
        let result = try await resource.isFullySigned(documentId: "doc1")
        XCTAssertFalse(result)
    }
}
