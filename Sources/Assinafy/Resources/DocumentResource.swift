import Foundation

/// Manages document uploads, status, artifact downloads, and lifecycle operations.
///
/// Access this resource through ``AssinafyClient/documents``.
///
/// ## Upload flow
/// 1. Upload a PDF with ``upload(_:options:)``
/// 2. Wait for processing with ``waitUntilReady(documentId:options:)``
/// 3. Create an assignment with ``AssinafyClient/assignments``
///
/// ## Example
/// ```swift
/// let doc = try await client.documents.upload(pdfData, options: DocumentUploadOptions(accountId: "acc"))
/// let ready = try await client.documents.waitUntilReady(documentId: doc.id)
/// ```
@objcMembers
public final class DocumentResource: BaseResource {

    private static let maxFileSizeBytes = 25 * 1024 * 1024
    private static let pdfMagicBytes: [UInt8] = [0x25, 0x50, 0x44, 0x46]

    // MARK: - Swift async API

    /// Uploads a PDF document for signature processing.
    ///
    /// Local validations are applied before the upload:
    /// - Must be a valid PDF (magic bytes).
    /// - Must not exceed 25 MB.
    ///
    /// - Parameters:
    ///   - data: The raw PDF `Data`.
    ///   - options: Optional account ID override.
    /// - Returns: The upload result containing the document ID and initial status.
    /// - Throws: ``ValidationError`` if file validation fails, ``APIError`` on HTTP failure.
    public func upload(_ data: Data, options: DocumentUploadOptions? = nil) async throws -> DocumentUploadResponse {
        try validatePDF(data)
        let id = try self.accountId(options?.accountId)
        let boundary = "AssinafyBoundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let body = Self.buildMultipartBody(file: data, filename: "document.pdf", boundary: boundary)

        let request = APIRequest(
            method: .post,
            path: "/accounts/\(id)/documents",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        return try await call("Failed to upload document", request: request)
    }

    private static func buildMultipartBody(file: Data, filename: String, boundary: String) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".utf8Data)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8Data)
        body.append("Content-Type: application/pdf\r\n\r\n".utf8Data)
        body.append(file)
        body.append("\r\n--\(boundary)--\r\n".utf8Data)
        return body
    }

    /// Lists documents in a workspace.
    ///
    /// - Parameters:
    ///   - params: Pagination and search options.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: A ``PaginatedResult`` of ``DocumentListItem`` objects.
    public func list(
        params: ListParams = ListParams(),
        accountId: String? = nil
    ) async throws -> PaginatedResult<DocumentListItem> {
        let id = try self.accountId(accountId)
        let items = params.toQueryItems()
        return try await callList("Failed to list documents",
                                  request: .get("/accounts/\(id)/documents",
                                                queryItems: items.isEmpty ? nil : items))
    }

    /// Lists documents in a workspace using the documented document filters.
    ///
    /// Mirrors `GET /accounts/{account_id}/documents` with `status`,
    /// `method`, `search`, `tags`, and `sort` filters.
    public func list(
        params: DocumentListParams,
        accountId: String? = nil
    ) async throws -> PaginatedResult<DocumentListItem> {
        let id = try self.accountId(accountId)
        let items = params.toQueryItems()
        return try await callList("Failed to list documents",
                                  request: .get("/accounts/\(id)/documents",
                                                queryItems: items.isEmpty ? nil : items))
    }

    /// Fetches full details for a document including assignment and activities.
    ///
    /// - Parameters:
    ///   - documentId: The unique document identifier.
    /// - Returns: ``DocumentDetails`` containing the current state and metadata.
    public func get(documentId: String) async throws -> DocumentDetails {
        let did = try requireId(documentId, name: "Document ID")
        return try await call("Failed to fetch document",
                              request: .get("/documents/\(did)"))
    }

    /// Polls the API until a document reaches `metadataReady` status or times out.
    ///
    /// - Parameters:
    ///   - documentId: The document to wait for.
    ///   - options: Timeout and polling interval configuration.
    /// - Returns: The ``DocumentUploadResponse`` when the document is ready.
    /// - Throws: ``AssinafySDKError`` if the document doesn't become ready in time.
    public func waitUntilReady(
        documentId: String,
        options: WaitUntilReadyOptions = WaitUntilReadyOptions()
    ) async throws -> DocumentUploadResponse {
        let did = try requireId(documentId, name: "Document ID")
        let deadline = Date().addingTimeInterval(options.maxWaitSeconds)
        let interval = UInt64(options.pollIntervalSeconds * 1_000_000_000)
        while true {
            let doc: DocumentUploadResponse = try await call(
                "Failed to fetch document",
                request: .get("/documents/\(did)")
            )
            switch doc.status {
            case .metadataReady, .pendingSignature, .certificating, .certificated:
                return doc
            case .failed:
                throw AssinafySDKError("Document processing failed",
                                       context: ["documentId": did, "status": doc.statusString])
            default:
                break
            }
            guard Date() < deadline else {
                throw AssinafySDKError(
                    "Document did not become ready within \(Int(options.maxWaitSeconds))s",
                    context: ["documentId": did, "status": doc.statusString]
                )
            }
            try await Task.sleep(nanoseconds: interval)
        }
    }

    /// Downloads a document artifact as raw `Data`.
    ///
    /// - Parameters:
    ///   - documentId: The document identifier.
    ///   - artifact: The artifact to download.
    /// - Returns: The raw binary content of the artifact.
    public func downloadArtifact(
        documentId: String,
        artifact: DocumentArtifactName
    ) async throws -> Data {
        let did = try requireId(documentId, name: "Document ID")
        return try await callData("Failed to download artifact",
                                  request: .get("/documents/\(did)/download/\(artifact.pathValue)"))
    }

    /// Downloads the thumbnail image for a document.
    ///
    /// - Parameters:
    ///   - documentId: The document identifier.
    /// - Returns: The raw image data (typically JPEG or PNG).
    public func downloadThumbnail(documentId: String) async throws -> Data {
        let did = try requireId(documentId, name: "Document ID")
        return try await callData("Failed to download thumbnail",
                                  request: .get("/documents/\(did)/thumbnail"))
    }

    /// Downloads a specific page of the document as an image.
    ///
    /// - Parameters:
    ///   - documentId: The document identifier.
    ///   - pageId: The page identifier returned by document metadata.
    /// - Returns: Raw image data for the requested page.
    public func downloadPage(
        documentId: String,
        pageId: String
    ) async throws -> Data {
        let did = try requireId(documentId, name: "Document ID")
        let pid = try requireId(pageId, name: "Page ID")
        return try await callData("Failed to download page",
                                  request: .get("/documents/\(did)/pages/\(pid)/download"))
    }

    /// Fetches the activity log for a document.
    ///
    /// - Parameters:
    ///   - documentId: The document identifier.
    /// - Returns: An array of ``DocumentActivity`` entries in chronological order.
    public func activities(
        documentId: String
    ) async throws -> [DocumentActivity] {
        let did = try requireId(documentId, name: "Document ID")
        let result: PaginatedResult<DocumentActivity> = try await callList(
            "Failed to fetch document activities",
            request: .get("/documents/\(did)/activities")
        )
        return result.data
    }

    /// Permanently deletes a document from the workspace.
    ///
    /// - Parameters:
    ///   - documentId: The document identifier.
    public func delete(documentId: String) async throws {
        let did = try requireId(documentId, name: "Document ID")
        try await callVoid("Failed to delete document",
                           request: .delete("/documents/\(did)"))
    }

    /// Creates a new document from a template with pre-assigned signers.
    ///
    /// - Parameters:
    ///   - templateId: The template to instantiate.
    ///   - signers: Mapping of role IDs to signer references.
    ///   - options: Optional name, message, and expiry.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: The newly created ``DocumentUploadResponse``.
    public func createFromTemplate(
        templateId: String,
        signers: [TemplateSigner],
        options: CreateDocumentFromTemplateOptions? = nil,
        accountId: String? = nil
    ) async throws -> DocumentUploadResponse {
        let id = try self.accountId(accountId)
        let tid = try requireId(templateId, name: "Template ID")
        struct Body: Encodable {
            let signers: [TemplateSigner]
            let name: String?
            let message: String?
            let expiresAt: String?
            let editorFields: [TemplateEditorField]?
            let tags: [String]?
            enum CodingKeys: String, CodingKey {
                case signers, name, message
                case expiresAt = "expires_at"
                case editorFields = "editor_fields"
                case tags
            }
        }
        let body = Body(signers: signers, name: options?.name,
                        message: options?.message, expiresAt: options?.expiresAt,
                        editorFields: options?.editorFields.isEmpty == false ? options?.editorFields : nil,
                        tags: options?.tags.isEmpty == false ? options?.tags : nil)
        let request = try APIRequest.post(
            "/accounts/\(id)/templates/\(tid)/documents", body: body
        )
        return try await call("Failed to create document from template", request: request)
    }

    /// Estimates the cost of signing all signers on a template document.
    ///
    /// - Parameters:
    ///   - templateId: The template identifier.
    ///   - signers: Template signer role mappings (cost purposes only).
    ///   - accountId: Override the client's default account ID.
    /// - Returns: A ``CostEstimate`` containing the price breakdown.
    public func estimateCostFromTemplate(
        templateId: String,
        signers: [TemplateSigner],
        accountId: String? = nil
    ) async throws -> CostEstimate {
        let id = try self.accountId(accountId)
        let tid = try requireId(templateId, name: "Template ID")
        struct Body: Encodable { let signers: [TemplateSigner] }
        let body = Body(signers: signers)
        let request = try APIRequest.post(
            "/accounts/\(id)/templates/\(tid)/documents/estimate-cost", body: body
        )
        return try await callCostEstimate("Failed to estimate template document cost", request: request)
    }

    /// Verifies the integrity of a signed document.
    ///
    /// - Parameters:
    ///   - signatureHash: The signature hash printed on a signed document.
    /// - Returns: `true` when the document's cryptographic signatures are valid.
    @discardableResult
    public func verify(signatureHash: String) async throws -> Bool {
        let hash = try requireId(signatureHash, name: "Signature hash")
        let result: VerifyResponse = try await call(
            "Failed to verify signature",
            request: .get("/documents/\(hash)/verify")
        )
        return result.isValid
    }

    /// Returns `true` when all signers on the document have signed.
    public func isFullySigned(documentId: String) async throws -> Bool {
        let details = try await get(documentId: documentId)
        guard let summary = details.assignment?.summary else { return false }
        return summary.completedCount >= summary.signerCount && summary.signerCount > 0
    }

    /// Computes signing progress as completed / total counts and a percentage.
    ///
    /// - Parameters:
    ///   - documentId: The document identifier.
    /// - Returns: A ``SigningProgress`` value suitable for display in a UI progress component.
    public func getSigningProgress(
        documentId: String
    ) async throws -> SigningProgress {
        let details = try await get(documentId: documentId)
        let total   = details.assignment?.summary?.signerCount ?? 0
        let signed  = details.assignment?.summary?.completedCount ?? 0
        let pending = total - signed
        let pct     = total > 0 ? (Double(signed) / Double(total)) * 100.0 : 0
        return SigningProgress(signed: signed, total: total, pending: pending, percentage: pct)
    }

    /// Lists every supported document status and whether documents in that
    /// status can be deleted.
    ///
    /// Mirrors `GET /documents/statuses`. Useful when you need to render UI
    /// controls (e.g. "delete" buttons) that depend on the deletability rule
    /// for the document's current state.
    public func listStatuses() async throws -> [DocumentStatusInfo] {
        let result: PaginatedResult<DocumentStatusInfo> = try await callList(
            "Failed to list document statuses",
            request: .get("/documents/statuses")
        )
        return result.data
    }

    /// Fetches the unauthenticated public summary of a document.
    ///
    /// Mirrors `GET /public/documents/{id}`. Safe to call before the signer
    /// has verified their access code.
    public func getPublicInfo(documentId: String) async throws -> PublicDocumentInfo {
        let did = try requireId(documentId, name: "Document ID")
        return try await call("Failed to fetch public document info",
                              request: .get("/public/documents/\(did)"))
    }

    /// Sends the 6-digit signing token to a signer via email or WhatsApp.
    ///
    /// Mirrors `PUT /public/documents/{id}/send-token`. No authentication is
    /// required; the SDK forwards the request as-is.
    @discardableResult
    public func sendPublicSignToken(
        documentId: String,
        payload: SendTokenPayload
    ) async throws -> SendTokenResponse {
        let did = try requireId(documentId, name: "Document ID")
        let request = try APIRequest.put("/public/documents/\(did)/send-token", body: payload)
        return try await call("Failed to send signing token", request: request)
    }

    /// Confirms a signer's data for a virtual assignment.
    ///
    /// Signers must confirm their data before they can sign the document.
    ///
    /// - Parameters:
    ///   - documentId: The document ID.
    ///   - signerAccessCode: The signer access code from the signing URL.
    ///   - payload: The data to confirm (email and/or WhatsApp phone number).
    public func confirmSignerData(
        documentId: String,
        signerAccessCode: String,
        payload: ConfirmSignerDataPayload
    ) async throws {
        let did = try requireId(documentId, name: "Document ID")
        let code = try requireId(signerAccessCode, name: "Signer access code")
        let items = [URLQueryItem(name: "signer-access-code", value: code)]
        let request = try APIRequest.put(
            "/documents/\(did)/signers/confirm-data",
            body: payload,
            queryItems: items
        )
        try await callVoid("Failed to confirm signer data", request: request)
    }

    // MARK: - Objective-C / completion-handler API

    /// Uploads a PDF document and delivers the result on the **main queue**.
    @objc(uploadDocument:accountId:completion:)
    public func upload(
        _ data: Data,
        accountId: String?,
        completion: @escaping (DocumentUploadResponse?, Error?) -> Void
    ) {
        let options = DocumentUploadOptions(accountId: accountId)
        withCompletion({ try await self.upload(data, options: options) }, completion: completion)
    }

    /// Lists documents and delivers the result on the **main queue**.
    @objc(listDocumentsWithAccountId:completion:)
    public func list(
        accountId: String?,
        completion: @escaping ([DocumentListItem]?, Error?) -> Void
    ) {
        withListCompletion({ try await self.list(accountId: accountId) }, completion: completion)
    }

    /// Fetches full document details and delivers the result on the **main queue**.
    @objc(getDocumentWithId:completion:)
    public func get(
        documentId: String,
        completion: @escaping (DocumentDetails?, Error?) -> Void
    ) {
        withCompletion({ try await self.get(documentId: documentId) }, completion: completion)
    }

    /// Deletes a document and notifies the **main queue** upon completion.
    @objc(deleteDocumentWithId:completion:)
    public func delete(
        documentId: String,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.delete(documentId: documentId) }, completion: completion)
    }

    // MARK: - Private

    private func validatePDF(_ data: Data) throws {
        guard data.count > 4 else {
            throw ValidationError("File data is empty or too small to be a PDF")
        }
        let header = [UInt8](data.prefix(4))
        guard header == DocumentResource.pdfMagicBytes else {
            throw ValidationError("File must be a valid PDF document")
        }
        guard data.count <= DocumentResource.maxFileSizeBytes else {
            throw ValidationError("File size must not exceed 25 MB")
        }
    }
}
