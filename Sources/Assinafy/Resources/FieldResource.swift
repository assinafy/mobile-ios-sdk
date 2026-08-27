import Foundation

private struct FieldValidationBody<Value: Encodable>: Encodable {
    let value: Value
}

/// Manages workspace field definitions.
///
/// Access this resource through ``AssinafyClient/fields``.
///
/// Field definitions describe the schema of an input value collected from
/// signers — for example a CPF, a date, or a free-text answer. The platform
/// ships a set of pre-defined definitions; workspaces can also create their
/// own via ``create(_:accountId:)``.
///
/// ## Example
/// ```swift
/// let field = try await client.fields.create(
///     CreateFieldPayload(type: "text", name: "Job title")
/// )
/// ```
@objcMembers
public final class FieldResource: BaseResource, @unchecked Sendable {

    // MARK: - Swift async API

    /// Creates a new field definition in the workspace.
    ///
    /// Mirrors `POST /accounts/{accountId}/fields`.
    public func create(
        _ payload: CreateFieldPayload,
        accountId: String? = nil
    ) async throws -> FieldDefinition {
        let id = try self.accountId(accountId)
        let request = try APIRequest.post("/accounts/\(id)/fields", body: payload)
        return try await call("Failed to create field", request: request)
    }

    /// Lists field definitions in the workspace.
    ///
    /// Mirrors `GET /accounts/{accountId}/fields`.
    public func list(
        params: FieldListParams = FieldListParams(),
        accountId: String? = nil
    ) async throws -> PaginatedResult<FieldDefinition> {
        let id = try self.accountId(accountId)
        let items = params.toQueryItems()
        return try await callList(
            "Failed to list fields",
            request: .get("/accounts/\(id)/fields", queryItems: items.isEmpty ? nil : items)
        )
    }

    /// Fetches a single field definition.
    ///
    /// Mirrors `GET /accounts/{accountId}/fields/{fieldId}`.
    public func get(fieldId: String, accountId: String? = nil) async throws -> FieldDefinition {
        let id = try self.accountId(accountId)
        let fid = try requireId(fieldId, name: "Field ID")
        return try await call("Failed to fetch field",
                              request: .get("/accounts/\(id)/fields/\(fid)"))
    }

    /// Updates a field definition.
    ///
    /// Mirrors `PUT /accounts/{accountId}/fields/{fieldId}`.
    public func update(
        fieldId: String,
        payload: UpdateFieldPayload,
        accountId: String? = nil
    ) async throws -> FieldDefinition {
        let id = try self.accountId(accountId)
        let fid = try requireId(fieldId, name: "Field ID")
        let request = try APIRequest.put("/accounts/\(id)/fields/\(fid)", body: payload)
        return try await call("Failed to update field", request: request)
    }

    /// Deletes a field definition.
    ///
    /// Mirrors `DELETE /accounts/{accountId}/fields/{fieldId}`. Fields that
    /// have been used in a signed document cannot be deleted.
    public func delete(fieldId: String, accountId: String? = nil) async throws {
        let id = try self.accountId(accountId)
        let fid = try requireId(fieldId, name: "Field ID")
        try await callVoid("Failed to delete field",
                           request: .delete("/accounts/\(id)/fields/\(fid)"))
    }

    /// Validates a value against a field definition.
    ///
    /// Mirrors `POST /accounts/{accountId}/fields/{fieldId}/validate`.
    /// Authenticated callers may omit `signerAccessCode`; signer-facing
    /// flows must pass the access code obtained from the signing URL.
    public func validate(
        fieldId: String,
        value: String,
        signerAccessCode: String? = nil,
        accountId: String? = nil
    ) async throws -> FieldValidationResult {
        try await validateValue(
            fieldId: fieldId,
            value: value,
            signerAccessCode: signerAccessCode,
            accountId: accountId
        )
    }

    /// Validates a value without narrowing the API's untyped JSON `value` field.
    @nonobjc public func validate(
        fieldId: String,
        value: JSONValue,
        signerAccessCode: String? = nil,
        accountId: String? = nil
    ) async throws -> FieldValidationResult {
        try await validateValue(
            fieldId: fieldId,
            value: value,
            signerAccessCode: signerAccessCode,
            accountId: accountId
        )
    }

    /// Validates multiple values in a single round-trip.
    ///
    /// Mirrors `POST /accounts/{accountId}/fields/validate-multiple`.
    public func validateMultiple(
        items: [FieldValidateMultipleItem],
        signerAccessCode: String? = nil,
        accountId: String? = nil
    ) async throws -> [FieldValidationResult] {
        let id = try self.accountId(accountId)
        guard !items.isEmpty else { throw ValidationError("items must not be empty") }
        for item in items {
            _ = try requireId(item.fieldId, name: "Field ID")
        }
        let queryItems: [URLQueryItem]? = signerAccessCode.flatMap {
            $0.isEmpty ? nil : [URLQueryItem(name: "signer-access-code", value: $0)]
        }
        let bodyData = try JSONEncoder.assinafy.encode(items)
        let request = APIRequest(
            method: .post,
            path: "/accounts/\(id)/fields/validate-multiple",
            queryItems: queryItems,
            body: bodyData
        )
        let result: PaginatedResult<FieldValidationResult> = try await callList(
            "Failed to validate fields",
            request: request
        )
        return result.data
    }

    /// Validates multiple values while preserving each value's JSON type.
    @nonobjc public func validateMultiple(
        items: [FieldJSONValidationItem],
        signerAccessCode: String? = nil,
        accountId: String? = nil
    ) async throws -> [FieldValidationResult] {
        let id = try self.accountId(accountId)
        guard !items.isEmpty else { throw ValidationError("items must not be empty") }
        for item in items {
            _ = try requireId(item.fieldId, name: "Field ID")
        }
        let queryItems: [URLQueryItem]? = signerAccessCode.flatMap {
            $0.isEmpty ? nil : [URLQueryItem(name: "signer-access-code", value: $0)]
        }
        let request = APIRequest(
            method: .post,
            path: "/accounts/\(id)/fields/validate-multiple",
            queryItems: queryItems,
            body: try JSONEncoder.assinafy.encode(items)
        )
        let result: PaginatedResult<FieldValidationResult> = try await callList(
            "Failed to validate fields",
            request: request
        )
        return result.data
    }

    /// Lists all supported field type codes and their display names.
    ///
    /// Mirrors `GET /field-types`.
    public func listFieldTypes() async throws -> [FieldTypeInfo] {
        let result: PaginatedResult<FieldTypeInfo> = try await callList(
            "Failed to list field types",
            request: .get("/field-types")
        )
        return result.data
    }

    private func validateValue<Value: Encodable>(
        fieldId: String,
        value: Value,
        signerAccessCode: String?,
        accountId: String?
    ) async throws -> FieldValidationResult {
        let id = try self.accountId(accountId)
        let fid = try requireId(fieldId, name: "Field ID")
        let queryItems: [URLQueryItem]? = signerAccessCode.flatMap {
            $0.isEmpty ? nil : [URLQueryItem(name: "signer-access-code", value: $0)]
        }
        let request = APIRequest(
            method: .post,
            path: "/accounts/\(id)/fields/\(fid)/validate",
            queryItems: queryItems,
            body: try JSONEncoder.assinafy.encode(FieldValidationBody(value: value))
        )
        return try await call("Failed to validate field", request: request)
    }

    // MARK: - Objective-C / completion-handler API

    /// Creates a field and delivers the result on the **main queue**.
    @objc(createField:accountId:completion:)
    public func create(
        _ payload: CreateFieldPayload,
        accountId: String?,
        completion: @escaping (FieldDefinition?, Error?) -> Void
    ) {
        withCompletion({ try await self.create(payload, accountId: accountId) }, completion: completion)
    }

    /// Lists fields and delivers the result on the **main queue**.
    @objc(listFieldsWithAccountId:completion:)
    public func list(
        accountId: String?,
        completion: @escaping ([FieldDefinition]?, Error?) -> Void
    ) {
        withListCompletion({ try await self.list(accountId: accountId) }, completion: completion)
    }

    /// Fetches a field by ID and delivers the result on the **main queue**.
    @objc(getFieldWithId:accountId:completion:)
    public func get(
        fieldId: String,
        accountId: String?,
        completion: @escaping (FieldDefinition?, Error?) -> Void
    ) {
        withCompletion({ try await self.get(fieldId: fieldId, accountId: accountId) }, completion: completion)
    }

    /// Deletes a field and notifies the **main queue** upon completion.
    @objc(deleteFieldWithId:accountId:completion:)
    public func delete(
        fieldId: String,
        accountId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.delete(fieldId: fieldId, accountId: accountId) }, completion: completion)
    }
}
