import Foundation

/// Manages reusable document templates.
///
/// Access this resource through ``AssinafyClient/templates``.
///
/// ## Example
/// ```swift
/// let templates = try await client.templates.list(accountId: "acc_id")
/// ```
@objcMembers
public final class TemplateResource: BaseResource {

    private static let maxFileSizeBytes = 25 * 1024 * 1024
    private static let pdfMagicBytes: [UInt8] = [0x25, 0x50, 0x44, 0x46]

    // MARK: - Swift async API

    /// Uploads a PDF as a new template.
    ///
    /// Mirrors `POST /accounts/{accountId}/templates`. The PDF is sent as a
    /// `multipart/form-data` request with `name` and `file` parts; the same
    /// PDF size/magic-byte validation that protects ``DocumentResource/upload(_:options:)``
    /// applies here.
    ///
    /// - Parameters:
    ///   - name: Human-readable name for the template.
    ///   - pdfData: Raw PDF bytes.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: The newly created ``TemplateDetails``.
    public func create(
        name: String,
        pdfData: Data,
        accountId: String? = nil
    ) async throws -> TemplateDetails {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError("Template name is required") }
        try validatePDF(pdfData)
        let id = try self.accountId(accountId)
        let boundary = "AssinafyBoundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let body = Self.buildMultipartBody(name: trimmed, file: pdfData, boundary: boundary)
        let request = APIRequest(
            method: .post,
            path: "/accounts/\(id)/templates",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        return try await call("Failed to create template", request: request)
    }

    /// Updates a template's metadata (name, default document name, default message).
    ///
    /// Mirrors `PUT /accounts/{accountId}/templates/{templateId}`.
    public func update(
        templateId: String,
        payload: UpdateTemplatePayload,
        accountId: String? = nil
    ) async throws -> TemplateDetails {
        let id = try self.accountId(accountId)
        let tid = try requireId(templateId, name: "Template ID")
        let request = try APIRequest.put("/accounts/\(id)/templates/\(tid)", body: payload)
        return try await call("Failed to update template", request: request)
    }

    /// Deletes a template.
    ///
    /// Mirrors `DELETE /accounts/{accountId}/templates/{templateId}`. The API
    /// rejects deletion when the template has documents linked to it.
    public func delete(templateId: String, accountId: String? = nil) async throws {
        let id = try self.accountId(accountId)
        let tid = try requireId(templateId, name: "Template ID")
        try await callVoid("Failed to delete template",
                           request: .delete("/accounts/\(id)/templates/\(tid)"))
    }

    /// Lists all templates in a workspace.
    ///
    /// - Parameters:
    ///   - params: Pagination and search options.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: A ``PaginatedResult`` of ``TemplateListItem`` objects.
    public func list(
        params: ListParams = ListParams(),
        accountId: String? = nil
    ) async throws -> PaginatedResult<TemplateListItem> {
        let id = try self.accountId(accountId)
        let items = params.toQueryItems()
        return try await callList("Failed to list templates",
                                  request: .get("/accounts/\(id)/templates",
                                                queryItems: items.isEmpty ? nil : items))
    }

    /// Fetches a template with its full role definitions.
    ///
    /// - Parameters:
    ///   - templateId: The unique template identifier.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: The ``TemplateDetails`` including roles.
    public func get(templateId: String, accountId: String? = nil) async throws -> TemplateDetails {
        let id = try self.accountId(accountId)
        let tid = try requireId(templateId, name: "Template ID")
        return try await call("Failed to fetch template",
                              request: .get("/accounts/\(id)/templates/\(tid)"))
    }

    // MARK: - Objective-C / completion-handler API

    /// Lists templates and delivers the result on the **main queue**.
    @objc(listTemplatesWithAccountId:completion:)
    public func list(
        accountId: String?,
        completion: @escaping ([TemplateListItem]?, Error?) -> Void
    ) {
        withListCompletion({ try await self.list(accountId: accountId) }, completion: completion)
    }

    /// Fetches a template by ID and delivers the result on the **main queue**.
    @objc(getTemplateWithId:accountId:completion:)
    public func get(
        templateId: String,
        accountId: String?,
        completion: @escaping (TemplateDetails?, Error?) -> Void
    ) {
        withCompletion({ try await self.get(templateId: templateId, accountId: accountId) }, completion: completion)
    }

    /// Deletes a template and notifies the **main queue** upon completion.
    @objc(deleteTemplateWithId:accountId:completion:)
    public func delete(
        templateId: String,
        accountId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.delete(templateId: templateId, accountId: accountId) }, completion: completion)
    }

    // MARK: - Private

    private func validatePDF(_ data: Data) throws {
        guard data.count > 4 else {
            throw ValidationError("File data is empty or too small to be a PDF")
        }
        let header = [UInt8](data.prefix(4))
        guard header == TemplateResource.pdfMagicBytes else {
            throw ValidationError("File must be a valid PDF document")
        }
        guard data.count <= TemplateResource.maxFileSizeBytes else {
            throw ValidationError("File size must not exceed 25 MB")
        }
    }

    private static func buildMultipartBody(name: String, file: Data, boundary: String) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".utf8Data)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".utf8Data)
        body.append(name.utf8Data)
        body.append("\r\n--\(boundary)\r\n".utf8Data)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(name).pdf\"\r\n".utf8Data)
        body.append("Content-Type: application/pdf\r\n\r\n".utf8Data)
        body.append(file)
        body.append("\r\n--\(boundary)--\r\n".utf8Data)
        return body
    }
}
