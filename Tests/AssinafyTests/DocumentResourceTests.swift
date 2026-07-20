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

    func testListSupportsDocumentSpecificFilters() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.list(
            params: DocumentListParams(
                status: "pending_signature",
                method: "virtual",
                search: "contract",
                tagIds: ["tag1", "tag2"],
                sort: "-updated_at",
                page: 2,
                perPage: 25
            )
        )
        let pairs = (mock.lastRequest?.queryItems ?? []).reduce(into: [String: String]()) { acc, item in
            acc[item.name] = item.value
        }
        XCTAssertEqual(pairs["status"], "pending_signature")
        XCTAssertEqual(pairs["method"], "virtual")
        XCTAssertEqual(pairs["search"], "contract")
        XCTAssertEqual(pairs["tags"], "tag1,tag2")
        XCTAssertEqual(pairs["sort"], "-updated_at")
        XCTAssertEqual(pairs["page"], "2")
        XCTAssertEqual(pairs["per-page"], "25")
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

    // MARK: - Artifact decoding

    func testArtifactsDecodeThumbnailURLWhenPresent() async throws {
        var dict = uploadResponseDict()
        dict["artifacts"] = [
            "original": "https://api.assinafy.com.br/v1/documents/doc1/download/original",
            "thumbnail": "https://api.assinafy.com.br/v1/documents/doc1/thumbnail",
        ]
        mock.stubEnvelope(dict)
        let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
        let resp = try await resource.upload(pdf)
        XCTAssertEqual(resp.artifacts.thumbnail,
                       "https://api.assinafy.com.br/v1/documents/doc1/thumbnail")
        XCTAssertNil(resp.artifacts.certificated)
    }

    func testArtifactsDecodeWithoutThumbnail() async throws {
        mock.stubEnvelope(uploadResponseDict())
        let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
        let resp = try await resource.upload(pdf)
        XCTAssertNil(resp.artifacts.thumbnail)
    }

    func testUploadResponseDecodesNumericTimestampsAndMissingAccountID() async throws {
        var dict = uploadResponseDict()
        dict.removeValue(forKey: "account_id")
        dict["created_at"] = 1633026554
        dict["updated_at"] = 1633026555
        dict["tags"] = [["id": "tag1", "name": "Contracts", "color": "#FF0000"]]
        mock.stubEnvelope(dict)
        let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
        let resp = try await resource.upload(pdf)
        XCTAssertNil(resp.accountId)
        XCTAssertEqual(resp.createdAt, "1633026554")
        XCTAssertEqual(resp.updatedAt, "1633026555")
        XCTAssertEqual(resp.tags.first?.name, "Contracts")
    }

    func testDocumentDetailsDecodeTagsAndAssignmentItems() async throws {
        mock.stubEnvelope([
            "id": "doc1",
            "account_id": "acc1",
            "name": "test.pdf",
            "status": "pending_signature",
            "assignment": [
                "id": "a1",
                "method": "collect",
                "signers": [
                    [
                        "id": "s1",
                        "full_name": "Signer",
                        "email": NSNull(),
                        "verification_method": "Whatsapp",
                        "notification_methods": ["Whatsapp"],
                    ]
                ],
                "items": [
                    [
                        "id": "i1",
                        "field": [
                            "id": "f1",
                            "name": "CPF",
                            "type": "cpf",
                        ],
                        "display_settings": ["top": 10],
                        "value": NSNull(),
                        "completed": false,
                    ]
                ],
                "summary": [
                    "signer_count": 1,
                    "completed_count": 0,
                    "signers": [
                        ["id": "s1", "full_name": "Signer", "email": NSNull(), "completed": false]
                    ],
                ],
                "signing_urls": [
                    ["signer_id": "s1", "url": "https://api.assinafy.com.br/v1/sign/code"]
                ],
            ],
            "pages": [],
            "tags": [["id": "tag1", "name": "Contracts"]],
            "created_at": 1633026554,
            "updated_at": 1633026555,
        ])
        let details = try await resource.get(documentId: "doc1")
        XCTAssertEqual(details.tags.first?.id, "tag1")
        XCTAssertEqual(details.assignment?.signers.first?.verificationMethod, "Whatsapp")
        XCTAssertEqual(details.assignment?.items.first?.field?.type, "cpf")
        XCTAssertEqual(details.assignment?.items.first?.displaySettings, "{\"top\":10}")
        XCTAssertEqual(details.assignment?.summary?.signers.count, 1)
        XCTAssertEqual(details.assignment?.signingUrls.first?.signerId, "s1")
        XCTAssertEqual(details.createdAt, "1633026554")
    }

    // MARK: - waitUntilReady

    func testWaitUntilReadyReturnsImmediatelyWhenStatusReady() async throws {
        var dict = uploadResponseDict()
        dict["status"] = "metadata_ready"
        mock.stubEnvelope(dict)
        _ = try await resource.waitUntilReady(documentId: "doc1")
        XCTAssertEqual(mock.allRequests.count, 1,
                       "waitUntilReady should not make a second GET when already ready")
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1")
    }

    func testWaitUntilReadyAcceptsPendingSignatureStatus() async throws {
        var dict = uploadResponseDict()
        dict["status"] = "pending_signature"
        mock.stubEnvelope(dict)
        let resp = try await resource.waitUntilReady(documentId: "doc1")
        XCTAssertEqual(resp.statusString, "pending_signature")
    }

    func testWaitUntilReadyThrowsImmediatelyWhenFailed() async {
        var dict = uploadResponseDict()
        dict["status"] = "failed"
        mock.stubEnvelope(dict)
        do {
            _ = try await resource.waitUntilReady(documentId: "doc1")
            XCTFail("Expected SDK error")
        } catch let error as AssinafySDKError {
            XCTAssertTrue(error.message.contains("failed"),
                          "Error message should mention failure, got: \(error.message)")
        } catch {
            XCTFail("Expected AssinafySDKError, got \(type(of: error))")
        }
    }

    func testWaitUntilReadyRejectsEmptyDocumentID() async {
        await assertThrowsValidationError {
            _ = try await self.resource.waitUntilReady(documentId: "")
        }
    }

    // MARK: - Statuses / public endpoints

    func testListStatusesUsesDocumentsStatusesEndpoint() async throws {
        mock.stubEnvelopeList([
            ["code": "metadata_ready", "deletable": true],
            ["code": "certificating", "deletable": false],
        ])
        let result = try await resource.listStatuses()
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].code, "metadata_ready")
        XCTAssertTrue(result[0].deletable)
        XCTAssertFalse(result[1].deletable)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/statuses")
    }

    func testGetPublicInfoUsesPublicEndpointAndDecodesStringPageCount() async throws {
        mock.stubEnvelope([
            "id": "doc1",
            "name": "1.pdf",
            "page_count": "1",
            "created_by": "John Smith",
        ])
        let info = try await resource.getPublicInfo(documentId: "doc1")
        XCTAssertEqual(info.id, "doc1")
        XCTAssertEqual(info.pageCount, 1)
        XCTAssertEqual(info.createdBy, "John Smith")
        XCTAssertEqual(mock.lastRequest?.path, "/public/documents/doc1")
    }

    func testSendPublicSignTokenSendsRecipientAndChannel() async throws {
        mock.stubEnvelope([
            "document": [
                "id": "doc1",
                "name": "1.pdf",
                "page_count": 1,
                "created_by": "John",
            ],
            "channel": "email",
            "recipient": "someone@example.com",
        ])
        let resp = try await resource.sendPublicSignToken(
            documentId: "doc1",
            payload: SendTokenPayload(recipient: "someone@example.com", channel: .email)
        )
        XCTAssertEqual(resp.channel, "email")
        XCTAssertEqual(resp.recipient, "someone@example.com")
        XCTAssertEqual(mock.lastRequest?.path, "/public/documents/doc1/send-token")
        XCTAssertEqual(mock.lastRequest?.method, .put)
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        // The documented body key is `email`; the default email channel omits `channel`.
        XCTAssertEqual(json["email"] as? String, "someone@example.com")
        XCTAssertNil(json["channel"])
        XCTAssertNil(json["recipient"])
    }

    func testSendPublicSignTokenWhatsappIncludesChannel() async throws {
        mock.stubEnvelope([
            "document": ["id": "doc1", "name": "Doc", "status": "pending_signature"],
            "channel": "whatsapp",
            "recipient": "+5548999990000",
        ])
        _ = try await resource.sendPublicSignToken(
            documentId: "doc1",
            payload: SendTokenPayload(recipient: "+5548999990000", channel: .whatsapp)
        )
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["email"] as? String, "+5548999990000")
        XCTAssertEqual(json["channel"] as? String, "whatsapp")
    }

    func testCreateFromTemplateSendsEditorFieldsTagsAndSignerStep() async throws {
        mock.stubEnvelope(uploadResponseDict())
        _ = try await resource.createFromTemplate(
            templateId: "tpl1",
            signers: [
                TemplateSigner(
                    roleId: "role1",
                    id: "s1",
                    verificationMethod: "Email",
                    notificationMethods: ["Email"],
                    step: NSNumber(value: 1)
                )
            ],
            options: CreateDocumentFromTemplateOptions(
                name: "Generated.pdf",
                message: "Please sign",
                expiresAt: "2026-06-01T00:00:00Z",
                editorFields: [TemplateEditorField(fieldId: "field1", value: "value1")],
                tags: ["Audit"]
            )
        )
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/templates/tpl1/documents")
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let signers = json["signers"] as? [[String: Any]],
              let editorFields = json["editor_fields"] as? [[String: Any]] else {
            XCTFail("No request body")
            return
        }
        XCTAssertEqual(signers.first?["step"] as? Int, 1)
        XCTAssertEqual(editorFields.first?["field_id"] as? String, "field1")
        XCTAssertEqual(json["tags"] as? [String], ["Audit"])
    }
}
