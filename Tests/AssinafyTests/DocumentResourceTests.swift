import XCTest
@testable import Assinafy

private final class SequenceHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    private var responses: [APIResponse]
    private(set) var requests: [APIRequest] = []

    init(_ responses: [APIResponse]) {
        self.responses = responses
    }

    func perform(_ request: APIRequest) async throws -> APIResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw ValidationError("Missing test response") }
        return responses.removeFirst()
    }
}

private func jsonResponse(_ object: [String: Any]) -> APIResponse {
    APIResponse(
        data: try! JSONSerialization.data(withJSONObject: object),
        headers: [:],
        statusCode: 200
    )
}

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
            "resource": "document",
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
            "resource": "document",
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

    func testSearchSupportsDocumentedPagination() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.search(
            search: "contract",
            status: "metadata_ready",
            page: 3,
            perPage: 20
        )
        let pairs = (mock.lastRequest?.queryItems ?? []).reduce(into: [String: String]()) {
            if let value = $1.value { $0[$1.name] = value }
        }
        XCTAssertEqual(pairs["search"], "contract")
        XCTAssertEqual(pairs["status"], "metadata_ready")
        XCTAssertEqual(pairs["page"], "3")
        XCTAssertEqual(pairs["per-page"], "20")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/test-account/documents/search")
    }

    func testSearchPreservesLegacySignatureWithoutPagination() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.search(
            search: "contract",
            status: "metadata_ready",
            accountId: "legacy-account"
        )
        let pairs = (mock.lastRequest?.queryItems ?? []).reduce(into: [String: String]()) {
            if let value = $1.value { $0[$1.name] = value }
        }
        XCTAssertEqual(pairs["search"], "contract")
        XCTAssertEqual(pairs["status"], "metadata_ready")
        XCTAssertNil(pairs["page"])
        XCTAssertNil(pairs["per-page"])
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/legacy-account/documents/search")
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

    // MARK: - Rename

    func testRenameAcceptsReservedCharactersAtMaximumLength() async throws {
        let name = String(repeating: "a", count: 250) + "/ ? #"
        XCTAssertEqual(name.count, 255)
        mock.stubEnvelope(documentDetailsDict())

        _ = try await resource.rename(documentId: "doc1", name: name)

        let body = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(json["name"], name)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1")
        XCTAssertEqual(mock.lastRequest?.method, .patch)
    }

    func testRenameRejectsEmptyNameBeforeRequest() async {
        await assertThrowsValidationError {
            _ = try await self.resource.rename(documentId: "doc1", name: "")
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testRenameRejectsNameLongerThan255CharactersBeforeRequest() async {
        await assertThrowsValidationError {
            _ = try await self.resource.rename(
                documentId: "doc1",
                name: String(repeating: "a", count: 256)
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testRenameStillRejectsUnsafePathIdentifierBeforeRequest() async {
        await assertThrowsValidationError {
            _ = try await self.resource.rename(documentId: "doc/1", name: "valid name")
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
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

    func testDownloadPadesArtifactUsesDocumentedPath() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        _ = try await resource.downloadArtifact(documentId: "doc1", artifact: .pades)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/doc1/download/pades")
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
        let isValid = try await resource.verify(signatureHash: "hash-1")
        XCTAssertTrue(isValid)
        XCTAssertEqual(mock.lastRequest?.path, "/documents/hash-1/verify")
        XCTAssertEqual(mock.lastRequest?.method, .get)
    }

    func testVerifyDetailsReturnsCompleteVerificationPayload() async throws {
        mock.stubEnvelope([
            "hash": "hash-1",
            "id": "doc1",
            "status": "certificated",
            "page_count": "2",
            "signer_count": "3",
            "completed_count": 3,
            "completed_at": "2026-08-20T12:00:00Z",
            "verified_at": "2026-08-21T12:00:00Z",
            "is_valid": true,
            "message": "",
        ])
        let result = try await resource.verifyDetails(signatureHash: "hash-1")
        XCTAssertEqual(result.signatureHash, "hash-1")
        XCTAssertEqual(result.id, "doc1")
        XCTAssertEqual(result.status, "certificated")
        XCTAssertEqual(result.pageCount, "2")
        XCTAssertEqual(result.signerCount, "3")
        XCTAssertEqual(result.completedCount, 3)
        XCTAssertEqual(result.completedAt, "2026-08-20T12:00:00Z")
        XCTAssertEqual(result.verifiedAt, "2026-08-21T12:00:00Z")
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.message, "")
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

    func testArtifactsDecodePadesURLWhenPresent() async throws {
        var dict = uploadResponseDict()
        dict["artifacts"] = [
            "original": "https://api.assinafy.com.br/v1/documents/doc1/download/original",
            "pades": "https://api.assinafy.com.br/v1/documents/doc1/download/pades",
        ]
        mock.stubEnvelope(dict)
        let response = try await resource.upload(Data("%PDF-1.7".utf8))
        XCTAssertEqual(
            response.artifacts.pades,
            "https://api.assinafy.com.br/v1/documents/doc1/download/pades"
        )
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
            "template_id": "template1",
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
                        "display_settings": [
                            "left": 5,
                            "top": 10,
                            "width": 200,
                            "height": 40,
                            "fontSize": 16,
                            "fontFamily": "Arial",
                            "backgroundColor": "#D5EBFF",
                        ],
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
        XCTAssertEqual(details.assignment?.items.first?.displaySettingsObject?.left, 5)
        XCTAssertEqual(details.assignment?.items.first?.displaySettingsObject?.fontSize, 16)
        XCTAssertEqual(details.assignment?.summary?.signers.count, 1)
        XCTAssertEqual(details.assignment?.signingUrls.first?.signerId, "s1")
        XCTAssertEqual(details.templateId, "template1")
        XCTAssertEqual(details.createdAt, "1633026554")
    }

    func testDocumentResponseVariantsDecodeDocumentedResourceRelationships() throws {
        let document: [String: Any] = [
            "resource": "document",
            "id": "doc1",
            "account_id": "account1",
            "template_id": "template1",
            "name": "contract.pdf",
            "status": "declined",
            "artifacts": ["original": "https://api.assinafy.com.br/document/original"],
            "is_closed": true,
            "signing_url": "https://api.assinafy.com.br/sign/document",
            "decline_reason": "Terms rejected",
            "declined_by": [
                "resource": "signer",
                "id": "signer1",
                "full_name": "Test Signer",
                "email": NSNull(),
                "whatsapp_phone_number": "+5500000000000",
                "has_accepted_terms": true,
            ],
            "tags": [["resource": "tag", "id": "tag1", "name": "Contracts"]],
            "assignment": [
                "resource": "assignment",
                "id": "assignment1",
                "method": "virtual",
                "signers": [],
            ],
            "pages": [],
            "created_at": "2026-08-20T12:00:00Z",
            "updated_at": "2026-08-21T12:00:00Z",
        ]
        let data = try JSONSerialization.data(withJSONObject: document)

        let listItem = try JSONDecoder.assinafy.decode(DocumentListItem.self, from: data)
        XCTAssertEqual(listItem.resource, "document")
        XCTAssertEqual(listItem.declinedBy?.resource, "signer")
        XCTAssertEqual(listItem.assignment?.resource, "assignment")
        XCTAssertEqual(listItem.signingUrl, "https://api.assinafy.com.br/sign/document")

        let upload = try JSONDecoder.assinafy.decode(DocumentUploadResponse.self, from: data)
        XCTAssertEqual(upload.resource, "document")
        XCTAssertEqual(upload.declinedBySigner?.whatsappPhoneNumber, "+5500000000000")
        XCTAssertEqual(upload.declinedBy?.fullName, "Test Signer")
        XCTAssertEqual(upload.assignment?.resource, "assignment")
        XCTAssertEqual(upload.signingUrl, "https://api.assinafy.com.br/sign/document")

        let details = try JSONDecoder.assinafy.decode(DocumentDetails.self, from: data)
        XCTAssertEqual(details.resource, "document")
        XCTAssertEqual(details.templateId, "template1")
        XCTAssertEqual(details.declinedBySigner?.resource, "signer")
        XCTAssertEqual(details.declinedBy?.id, "signer1")
        XCTAssertEqual(details.assignment?.resource, "assignment")
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

    func testWaitUntilReadyRejectsUnsafeIntervalsBeforeRequest() async {
        let invalidOptions = [
            WaitUntilReadyOptions(maxWaitSeconds: 0, pollIntervalSeconds: 1),
            WaitUntilReadyOptions(maxWaitSeconds: .infinity, pollIntervalSeconds: 1),
            WaitUntilReadyOptions(maxWaitSeconds: 1, pollIntervalSeconds: 0),
            WaitUntilReadyOptions(maxWaitSeconds: 1, pollIntervalSeconds: -.infinity),
            WaitUntilReadyOptions(maxWaitSeconds: 1, pollIntervalSeconds: .nan),
        ]
        for options in invalidOptions {
            do {
                _ = try await resource.waitUntilReady(documentId: "doc1", options: options)
                XCTFail("Expected ValidationError")
            } catch is ValidationError {
            } catch {
                XCTFail("Expected ValidationError, got \(type(of: error))")
            }
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
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

    func testGetPublicInfoDecodesCompleteDocumentSchema() async throws {
        mock.stubEnvelope([
            "resource": "document",
            "id": "doc1",
            "account_id": "account1",
            "template_id": "template1",
            "name": "contract.pdf",
            "status": "pending_signature",
            "artifacts": [
                "original": "https://api.assinafy.com.br/v1/documents/doc1/download/original",
                "pades": "https://api.assinafy.com.br/v1/documents/doc1/download/pades",
            ],
            "is_closed": false,
            "signing_url": "https://api.assinafy.com.br/v1/sign/doc1",
            "decline_reason": NSNull(),
            "tags": [["id": "tag1", "name": "Contracts"]],
            "assignment": ["id": "assignment1", "method": "virtual", "signers": []],
            "pages": [[
                "id": "page1",
                "number": 1,
                "height": 2100,
                "width": 1275,
                "download_url": "https://api.assinafy.com.br/v1/documents/doc1/pages/page1/download",
            ]],
            "created_at": "2026-08-20T12:00:00Z",
            "updated_at": "2026-08-21T12:00:00Z",
        ])
        let document = try await resource.getPublicInfo(documentId: "doc1")
        XCTAssertEqual(document.resource, "document")
        XCTAssertEqual(document.accountId, "account1")
        XCTAssertEqual(document.templateId, "template1")
        XCTAssertEqual(document.status, .pendingSignature)
        XCTAssertEqual(document.statusString, "pending_signature")
        XCTAssertEqual(document.artifacts?.pades,
                       "https://api.assinafy.com.br/v1/documents/doc1/download/pades")
        XCTAssertEqual(document.tags.first?.id, "tag1")
        XCTAssertEqual(document.assignment?.id, "assignment1")
        XCTAssertEqual(document.pages.first?.id, "page1")
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertEqual(document.createdAt, "2026-08-20T12:00:00Z")
        XCTAssertEqual(document.updatedAt, "2026-08-21T12:00:00Z")
    }

    func testSendPublicSignTokenHandlesBareEnvelopeAndFetchesDocument() async throws {
        let client = SequenceHTTPClient([
            jsonResponse(["status": 200, "message": ""]),
            jsonResponse([
                "status": 200,
                "message": "",
                "data": [
                    "id": "doc1",
                    "name": "contract.pdf",
                    "status": "pending_signature",
                    "pages": [],
                    "created_at": "2026-08-20T12:00:00Z",
                    "updated_at": "2026-08-21T12:00:00Z",
                ],
            ]),
        ])
        let publicResource = DocumentResource(http: client)
        let response = try await publicResource.sendPublicSignToken(
            documentId: "doc1",
            payload: SendTokenPayload(recipient: "recipient@example.invalid", channel: .email)
        )
        XCTAssertEqual(response.document.id, "doc1")
        XCTAssertEqual(response.document.status, .pendingSignature)
        XCTAssertEqual(response.channel, "email")
        XCTAssertEqual(response.recipient, "recipient@example.invalid")
        XCTAssertEqual(client.requests.map(\.path), [
            "/public/documents/doc1/send-token",
            "/public/documents/doc1",
        ])
        XCTAssertEqual(client.requests.first?.method, .put)
        guard let body = client.requests.first?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["email"] as? String, "recipient@example.invalid")
        XCTAssertNil(json["channel"])
        XCTAssertNil(json["recipient"])
    }

    func testSendPublicSignTokenUsesSandboxCompatibilityShapeWhenConfigured() async throws {
        let response = jsonResponse([
            "status": 200,
            "message": "",
            "data": ["id": "doc1", "name": "contract.pdf", "status": "pending_signature"],
        ])
        let client = SequenceHTTPClient([response, response])
        let publicResource = DocumentResource(http: client, usesSandboxCompatibility: true)
        _ = try await publicResource.sendPublicSignToken(
            documentId: "doc1",
            payload: SendTokenPayload(recipient: "recipient@example.invalid")
        )
        let body = try XCTUnwrap(client.requests.first?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["email"] as? String, "recipient@example.invalid")
        XCTAssertEqual(json["recipient"] as? String, "recipient@example.invalid")
        XCTAssertEqual(json["channel"] as? String, "email")
    }

    func testSendPublicSignTokenPreservesLegacyWhatsappChannel() async throws {
        let publicDocumentResponse = jsonResponse([
            "status": 200,
            "message": "",
            "data": ["id": "doc1", "name": "contract.pdf", "status": "pending_signature"],
        ])
        let client = SequenceHTTPClient([publicDocumentResponse, publicDocumentResponse])
        let publicResource = DocumentResource(http: client)
        _ = try await publicResource.sendPublicSignToken(
            documentId: "doc1",
            payload: SendTokenPayload(recipient: "+15555550101", channel: .whatsapp)
        )
        guard let body = client.requests.first?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["email"] as? String, "+15555550101")
        XCTAssertEqual(json["channel"] as? String, "whatsapp")
        XCTAssertNil(json["recipient"])
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

    func testCreateFromTemplateRequiresRoleAndSignerIDsBeforeRequest() async {
        let invalidSigners = [
            TemplateSigner(roleId: "", id: "signer1"),
            TemplateSigner(roleId: "role1"),
            TemplateSigner(roleId: "role1", id: "  "),
        ]
        for signer in invalidSigners {
            do {
                _ = try await resource.createFromTemplate(templateId: "template1", signers: [signer])
                XCTFail("Expected ValidationError")
            } catch is ValidationError {
            } catch {
                XCTFail("Expected ValidationError, got \(type(of: error))")
            }
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testTemplateEstimateRequiresRoleAndOmitsSignerIdentity() async throws {
        mock.stubEnvelope(["total_credits": 0, "has_sufficient_resources": true])
        _ = try await resource.estimateCostFromTemplate(
            templateId: "template1",
            signers: [
                TemplateSigner(
                    roleId: "role1",
                    id: "signer-id-must-not-be-sent",
                    verificationMethod: "Whatsapp",
                    notificationMethods: ["Email", "Whatsapp"],
                    step: NSNumber(value: 2)
                )
            ]
        )
        let body = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let signer = try XCTUnwrap((json["signers"] as? [[String: Any]])?.first)
        XCTAssertEqual(signer["role_id"] as? String, "role1")
        XCTAssertEqual(signer["verification_method"] as? String, "Whatsapp")
        XCTAssertEqual(signer["notification_methods"] as? [String], ["Email", "Whatsapp"])
        XCTAssertNil(signer["id"])
        XCTAssertNil(signer["step"])

        let requestCount = mock.allRequests.count
        await assertThrowsValidationError {
            _ = try await self.resource.estimateCostFromTemplate(
                templateId: "template1",
                signers: [TemplateSigner(roleId: "")]
            )
        }
        XCTAssertEqual(mock.allRequests.count, requestCount)
    }
}
