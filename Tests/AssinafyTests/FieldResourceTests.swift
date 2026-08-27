import XCTest
@testable import Assinafy

final class FieldResourceTests: XCTestCase {
    var mock: MockHTTPClient!
    var resource: FieldResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        resource = FieldResource(http: mock, defaultAccountId: "acc1")
    }

    private func fieldDict(id: String = "f1") -> [String: Any] {
        [
            "resource": "field",
            "id": id,
            "name": "Custom Field",
            "type": "text",
            "regex": NSNull(),
            "is_pre_defined": false,
            "is_active": true,
            "is_required": true,
            "is_standard": false,
            "is_read_only": false,
            "is_visible": true,
        ]
    }

    func testCreatePostsToFieldsEndpoint() async throws {
        mock.stubEnvelope(fieldDict())
        _ = try await resource.create(CreateFieldPayload(type: "text", name: "Custom Field"))
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/fields")
    }

    func testCreateEncodesOnlyDocumentedFields() async throws {
        mock.stubEnvelope(fieldDict())
        _ = try await resource.create(CreateFieldPayload(
            type: "text",
            name: "Custom",
            regex: "/[0-9]{5}/",
            isRequired: false,
            isActive: true
        ))
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["type"] as? String, "text")
        XCTAssertEqual(json["name"] as? String, "Custom")
        XCTAssertEqual(json["regex"] as? String, "/[0-9]{5}/")
        XCTAssertEqual(json["is_required"] as? Bool, false)
        XCTAssertNil(json["is_active"])
    }

    func testCreatePreservesLiveIsActiveFalseExtension() async throws {
        mock.stubEnvelope(fieldDict())
        _ = try await resource.create(
            CreateFieldPayload(type: "text", name: "Inactive", isActive: false)
        )
        let data = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["is_active"] as? Bool, false)
    }

    func testListAppliesIncludeFlags() async throws {
        mock.stubEnvelopeList([fieldDict()])
        _ = try await resource.list(params: FieldListParams(includeInactive: true, includeStandard: true))
        let queryNames = mock.lastRequest?.queryItems?.map(\.name) ?? []
        XCTAssertTrue(queryNames.contains("include_inactive"))
        XCTAssertTrue(queryNames.contains("include_standard"))
    }

    func testListOmitsFlagsWhenFalse() async throws {
        mock.stubEnvelopeList([fieldDict()])
        _ = try await resource.list()
        XCTAssertNil(mock.lastRequest?.queryItems)
    }

    func testGetUsesCorrectPath() async throws {
        mock.stubEnvelope(fieldDict())
        let field = try await resource.get(fieldId: "f1")
        XCTAssertEqual(field.resource, "field")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/fields/f1")
    }

    func testGetRejectsEmptyID() async {
        await assertThrowsValidationError {
            _ = try await self.resource.get(fieldId: "")
        }
    }

    func testUpdateEncodesOnlyProvidedFields() async throws {
        mock.stubEnvelope(fieldDict())
        _ = try await resource.update(
            fieldId: "f1",
            payload: UpdateFieldPayload(name: "Renamed")
        )
        XCTAssertEqual(mock.lastRequest?.method, .put)
        guard let body = mock.lastRequest?.body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            XCTFail("No body")
            return
        }
        XCTAssertEqual(json["name"] as? String, "Renamed")
        XCTAssertNil(json["type"])
        XCTAssertNil(json["regex"])
        XCTAssertNil(json["is_required"])
        XCTAssertNil(json["is_active"])
    }

    func testUpdatePreservesLiveCompatibleExtensionFields() async throws {
        mock.stubEnvelope(fieldDict())
        _ = try await resource.update(
            fieldId: "f1",
            payload: UpdateFieldPayload(
                type: "date",
                isRequired: NSNumber(value: true),
                isActive: NSNumber(value: false)
            )
        )
        let data = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "date")
        XCTAssertEqual(json["is_required"] as? Bool, true)
        XCTAssertEqual(json["is_active"] as? Bool, false)
    }

    func testUpdateCanExplicitlyClearRegex() async throws {
        mock.stubEnvelope(fieldDict())
        _ = try await resource.update(
            fieldId: "f1",
            payload: UpdateFieldPayload(regex: "ignored", clearsRegex: true)
        )
        let data = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(json["regex"] is NSNull)
    }

    func testDeleteUsesDeleteMethod() async throws {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 204))
        try await resource.delete(fieldId: "f1")
        XCTAssertEqual(mock.lastRequest?.method, .delete)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/fields/f1")
    }

    func testValidateSendsValueAndDecodesResult() async throws {
        mock.stubEnvelope([
            "type": "cpf",
            "success": true,
            "error_message": "",
        ])
        let result = try await resource.validate(
            fieldId: "f1",
            value: "400.676.228-36",
            signerAccessCode: "abc"
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.type, "cpf")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/fields/f1/validate")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.name, "signer-access-code")
        XCTAssertEqual(mock.lastRequest?.queryItems?.first?.value, "abc")
    }

    func testValidateOmitsAccessCodeWhenNil() async throws {
        mock.stubEnvelope(["type": "text", "success": true, "error_message": ""])
        _ = try await resource.validate(fieldId: "f1", value: "v")
        XCTAssertNil(mock.lastRequest?.queryItems)
    }

    func testValidateMultipleSendsArray() async throws {
        mock.stubEnvelopeList([
            ["field_id": "f1", "type": "cpf", "success": false, "error_message": "Invalid CPF."],
            ["field_id": "f2", "type": "email", "success": true, "error_message": ""],
        ])
        let results = try await resource.validateMultiple(
            items: [
                FieldValidateMultipleItem(fieldId: "f1", value: "bad"),
                FieldValidateMultipleItem(fieldId: "f2", value: "ok@ok"),
            ],
            signerAccessCode: "abc"
        )
        XCTAssertEqual(results.count, 2)
        XCTAssertFalse(results[0].success)
        XCTAssertEqual(results[0].fieldId, "f1")
        XCTAssertTrue(results[1].success)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc1/fields/validate-multiple")
        guard let body = mock.lastRequest?.body,
              let arr = try? JSONSerialization.jsonObject(with: body) as? [[String: Any]] else {
            XCTFail("No array body")
            return
        }
        XCTAssertEqual(arr[0]["field_id"] as? String, "f1")
        XCTAssertEqual(arr[1]["value"] as? String, "ok@ok")
    }

    func testValidateMultipleRejectsEmpty() async {
        await assertThrowsValidationError {
            _ = try await self.resource.validateMultiple(items: [FieldValidateMultipleItem]())
        }
    }

    func testValidatePreservesJSONValueTypes() async throws {
        mock.stubEnvelope(["type": "number", "success": true, "error_message": ""])
        _ = try await resource.validate(
            fieldId: "f1",
            value: JSONValue(.number(1.25))
        )
        let body = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["value"] as? Double, 1.25)
    }

    func testValidateMultiplePreservesNestedJSONValues() async throws {
        mock.stubEnvelopeList([
            ["field_id": "f1", "type": "object", "success": true, "error_message": ""],
        ])
        _ = try await resource.validateMultiple(items: [
            FieldJSONValidationItem(
                fieldId: "f1",
                value: JSONValue(.object(["approved": JSONValue(.bool(true))]))
            ),
        ])
        let body = try XCTUnwrap(mock.lastRequest?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        let value = try XCTUnwrap(json.first?["value"] as? [String: Any])
        XCTAssertEqual(value["approved"] as? Bool, true)
    }

    func testListFieldTypesUsesFieldTypesPath() async throws {
        mock.stubEnvelopeList([
            ["type": "cpf", "name": "CPF"],
            ["type": "text", "name": "Text"],
        ])
        let types = try await resource.listFieldTypes()
        XCTAssertEqual(types.count, 2)
        XCTAssertEqual(types[0].type, "cpf")
        XCTAssertEqual(mock.lastRequest?.path, "/field-types")
    }

    // MARK: - Decoding

    func testFieldDefinitionDecodesAllFlags() throws {
        let json: [String: Any] = [
            "id": "f1",
            "name": "Name",
            "type": "personName",
            "regex": NSNull(),
            "is_pre_defined": true,
            "is_active": false,
            "is_required": true,
            "is_standard": true,
            "is_read_only": true,
            "is_visible": false,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let f = try JSONDecoder().decode(FieldDefinition.self, from: data)
        XCTAssertTrue(f.isPreDefined)
        XCTAssertFalse(f.isActive)
        XCTAssertTrue(f.isRequired)
        XCTAssertTrue(f.isStandard)
        XCTAssertTrue(f.isReadOnly)
        XCTAssertFalse(f.isVisible)
    }
}
