import XCTest
@testable import Assinafy

final class TemplateResourceTests: XCTestCase {
    var mock: MockHTTPClient!
    var resource: TemplateResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        resource = TemplateResource(http: mock, defaultAccountId: "acc1")
    }

    private func templateDict(id: String = "t1") -> [String: Any] {
        [
            "resource": "template",
            "id": id,
            "name": "My Template",
            "status": "Ready",
            "document_name": "doc.pdf",
            "message": "Sign please",
            "roles": [],
            "created_at": "2024-01-01",
            "updated_at": "2024-01-01",
        ]
    }

    func testListUsesTemplatesEndpoint() async throws {
        mock.stubEnvelopeList([templateDict()])
        let result = try await resource.list()
        XCTAssertEqual(result.data.first?.resource, "template")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/templates")
    }

    func testListEncodesAllConfiguredFilters() async throws {
        mock.stubEnvelopeList([])
        _ = try await resource.list(
            params: TemplateListParams(
                status: "ready",
                search: "contract",
                tagIds: ["tag1", "tag2"],
                sort: "updated_at",
                page: 2,
                perPage: 25
            )
        )
        let pairs = (mock.lastRequest?.queryItems ?? []).reduce(into: [String: String]()) { acc, item in
            acc[item.name] = item.value
        }
        XCTAssertEqual(pairs["search"], "contract")
        XCTAssertEqual(pairs["page"], "2")
        XCTAssertEqual(pairs["per-page"], "25")
        XCTAssertEqual(pairs["status"], "ready")
        XCTAssertEqual(pairs["tags"], "tag1,tag2")
        XCTAssertEqual(pairs["sort"], "updated_at")
    }

    func testGetUsesCorrectPath() async throws {
        var dict = templateDict()
        dict["pages"] = [
            [
                "id": "p1",
                "number": 1,
                "height": 2100,
                "width": 1275,
                "download_url": "https://api.assinafy.com.br/page",
                "fields": [
                    [
                        "id": "fp1",
                        "field_id": "f1",
                        "role_id": "r1",
                        "label": "Name",
                        "display_settings": ["left": 10],
                        "created_at": "2024-07-19T15:23:03Z",
                        "updated_at": "2024-07-19T15:23:03Z",
                    ],
                ],
            ],
        ]
        dict["roles"] = [
            [
                "id": "r1",
                "name": "Signer",
                "assignment_type": "Signer",
                "created_at": "2024-07-19T15:23:03Z",
                "updated_at": "2024-07-19T15:23:03Z",
            ],
        ]
        dict["tags"] = [["id": "tag1", "name": "HR"]]
        dict["default_document_tags"] = [["id": "tag2", "name": "Contracts"]]
        mock.stubEnvelope(dict)
        let details = try await resource.get(templateId: "t1")
        XCTAssertEqual(details.resource, "template")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/templates/t1")
        XCTAssertEqual(details.documentName, "doc.pdf")
        XCTAssertEqual(details.message, "Sign please")
        XCTAssertEqual(details.pages.first?.fields.first?.fieldId, "f1")
        XCTAssertEqual(details.roles?.first?.assignmentType, "Signer")
        XCTAssertEqual(details.tags.first?.name, "HR")
        XCTAssertEqual(details.defaultDocumentTags.first?.name, "Contracts")
    }

    func testCreateRejectsEmptyName() async {
        await assertThrowsValidationError {
            _ = try await self.resource.create(name: "", pdfData: Data([0x25, 0x50, 0x44, 0x46, 0x2D]))
        }
    }

    func testCreateRejectsNonPDF() async {
        await assertThrowsValidationError {
            _ = try await self.resource.create(name: "T", pdfData: Data([0x00, 0x01]))
        }
    }

    func testCreatePostsMultipartWithNameAndFile() async throws {
        mock.stubEnvelope(templateDict())
        let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
        _ = try await resource.create(name: "My Template", pdfData: pdf)
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/templates")
        XCTAssertTrue(mock.lastRequest?.contentType.hasPrefix("multipart/form-data; boundary=") == true)
        let bodyString = String(data: mock.lastRequest?.body ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(bodyString.contains("name=\"name\""))
        XCTAssertTrue(bodyString.contains("My Template"))
        XCTAssertTrue(bodyString.contains("name=\"file\""))
        XCTAssertTrue(bodyString.contains("Content-Type: application/pdf"))
    }

    func testUpdateSendsOnlyProvidedFields() async throws {
        mock.stubEnvelope(templateDict())
        _ = try await resource.update(
            templateId: "t1",
            payload: UpdateTemplatePayload(name: "Renamed")
        )
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/templates/t1")
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["name"] as? String, "Renamed")
        XCTAssertNil(json["document_name"])
        XCTAssertNil(json["message"])
    }

    func testDeleteUsesCorrectPath() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
        try await resource.delete(templateId: "t1")
        XCTAssertEqual(mock.lastRequest?.method, .delete)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/templates/t1")
    }

    func testDeleteRejectsEmptyID() async {
        await assertThrowsValidationError {
            try await self.resource.delete(templateId: "")
        }
    }

    func testTemplateCreationSignerRequiresExistingSignerID() {
        XCTAssertThrowsError(
            try TemplateSigner(roleId: "role1").validateForDocumentCreation()
        )
        XCTAssertNoThrow(
            try TemplateSigner(roleId: "role1", id: "signer1").validateForDocumentCreation()
        )
    }

    func testTemplateCostSignerRequiresRoleAndOmitsCreateOnlyFields() throws {
        XCTAssertThrowsError(
            try TemplateSigner(roleId: " ").costEstimatePayload()
        )
        let signer = TemplateSigner(
            roleId: "role1",
            id: "signer1",
            verificationMethod: "Email",
            notificationMethods: ["Email"],
            step: NSNumber(value: 2)
        )
        let data = try JSONEncoder.assinafy.encode(try signer.costEstimatePayload())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["role_id"] as? String, "role1")
        XCTAssertEqual(json["verification_method"] as? String, "Email")
        XCTAssertNil(json["id"])
        XCTAssertNil(json["step"])
    }
}
