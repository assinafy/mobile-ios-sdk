import Foundation

private let emailPattern = "^[A-Z0-9a-z._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$"

/// Manages signer records within a workspace.
///
/// Access this resource through ``AssinafyClient/signers``.
///
/// ## Idempotent creation
/// ``create(_:accountId:)`` first searches for an existing signer with the same
/// email address. If one is found it is returned without creating a duplicate.
///
/// ## Example
/// ```swift
/// let signer = try await client.signers.create(
///     CreateSignerPayload(fullName: "John Doe", email: "john@example.com")
/// )
/// ```
@objcMembers
public final class SignerResource: BaseResource {

    // MARK: - Swift async API

    /// Creates a signer in the workspace, or returns the existing signer if the email already exists.
    ///
    /// - Parameters:
    ///   - payload: The signer creation payload.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: The newly created or pre-existing ``Signer``.
    /// - Throws: ``ValidationError`` for invalid input, ``APIError`` on HTTP failure.
    public func create(
        _ payload: CreateSignerPayload,
        accountId: String? = nil
    ) async throws -> Signer {
        try validateCreatePayload(payload)
        let id = try self.accountId(accountId)

        if let email = payload.email {
            if let existing = try await findByEmail(email, accountId: id) {
                logger.info("Using existing signer", context: ["signerId": existing.id])
                return existing
            }
        }

        logger.info("Creating signer")
        do {
            let request = try APIRequest.post("/accounts/\(id)/signers", body: payload)
            return try await call("Failed to create signer", request: request)
        } catch let error as APIError where error.statusCode == 409 {
            if let email = payload.email {
                if let duplicate = try await findByEmail(email, accountId: id) {
                    logger.info("Signer already exists, reusing", context: ["signerId": duplicate.id])
                    return duplicate
                }
            }
            throw error
        }
    }

    /// Fetches a signer by their ID.
    ///
    /// - Parameters:
    ///   - signerId: The unique signer identifier.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: The matching ``Signer``.
    public func get(signerId: String, accountId: String? = nil) async throws -> Signer {
        let id = try self.accountId(accountId)
        let sid = try requireId(signerId, name: "Signer ID")
        return try await call("Failed to fetch signer",
                              request: .get("/accounts/\(id)/signers/\(sid)"))
    }

    /// Lists all signers in the workspace.
    ///
    /// - Parameters:
    ///   - params: Pagination and search parameters.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: A ``PaginatedResult`` containing ``Signer`` objects.
    public func list(
        params: ListParams = ListParams(),
        accountId: String? = nil
    ) async throws -> PaginatedResult<Signer> {
        let id = try self.accountId(accountId)
        let items = params.toQueryItems()
        return try await callList("Failed to list signers",
                                  request: .get("/accounts/\(id)/signers",
                                                queryItems: items.isEmpty ? nil : items))
    }

    /// Updates a signer's details.
    ///
    /// - Parameters:
    ///   - signerId: The ID of the signer to update.
    ///   - payload: Fields to change.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: The updated ``Signer``.
    public func update(
        signerId: String,
        payload: UpdateSignerPayload,
        accountId: String? = nil
    ) async throws -> Signer {
        let id = try self.accountId(accountId)
        let sid = try requireId(signerId, name: "Signer ID")
        let request = try APIRequest.put("/accounts/\(id)/signers/\(sid)", body: payload)
        return try await call("Failed to update signer", request: request)
    }

    /// Deletes a signer from the workspace.
    ///
    /// - Parameters:
    ///   - signerId: The ID of the signer to delete.
    ///   - accountId: Override the client's default account ID.
    public func delete(signerId: String, accountId: String? = nil) async throws {
        let id = try self.accountId(accountId)
        let sid = try requireId(signerId, name: "Signer ID")
        try await callVoid("Failed to delete signer",
                           request: .delete("/accounts/\(id)/signers/\(sid)"))
    }

    /// Searches for a signer by email address.
    ///
    /// The comparison is case-insensitive.
    ///
    /// - Parameters:
    ///   - email: The email address to search for.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: The matching ``Signer``, or `nil` if none exists.
    public func findByEmail(_ email: String, accountId: String? = nil) async throws -> Signer? {
        try assertValidEmail(email)
        do {
            let params = ListParams(perPage: 100, search: email)
            let result = try await list(params: params, accountId: accountId)
            let lower = email.lowercased()
            return result.data.first { $0.email?.lowercased() == lower }
        } catch let error as APIError where error.statusCode == 404 {
            return nil
        }
    }

    // MARK: - Signer Self-Service (signer-facing flows)

    /// Fetches the signer's own information using a signer access code.
    ///
    /// - Parameter signerAccessCode: The signer access code from the signing URL.
    /// - Returns: ``SignerSelfInfo`` with additional fields like `hasSignature` and `hasInitial`.
    public func getSelf(signerAccessCode: String) async throws -> SignerSelfInfo {
        let code = try requireId(signerAccessCode, name: "Signer access code")
        let items = [URLQueryItem(name: "signer-access-code", value: code)]
        return try await call("Failed to fetch signer self info",
                              request: .get("/signers/self", queryItems: items))
    }

    /// Allows a signer to accept the terms of use.
    ///
    /// - Parameter signerAccessCode: The signer access code from the signing URL.
    /// - Returns: ``AcceptTermsResponse`` confirming acceptance. The current
    ///   API returns no profile data, so legacy `fullName` and `email` values
    ///   are empty unless an older server includes them.
    public func acceptTerms(signerAccessCode: String) async throws -> AcceptTermsResponse {
        let code = try requireId(signerAccessCode, name: "Signer access code")
        let request = APIRequest(
            method: .put,
            path: "/signers/accept-terms",
            queryItems: [URLQueryItem(name: "signer-access-code", value: code)]
        )
        let data = try await callData("Failed to accept terms", request: request)
        guard !data.isEmpty else {
            return AcceptTermsResponse(fullName: "", email: "", hasAcceptedTerms: true)
        }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["status"] != nil || object["message"] != nil || object["data"] != nil,
           let envelope = try? JSONDecoder.assinafy.decode(
               AssinafyEnvelope<AcceptTermsResponse>.self,
               from: data
           ) {
            if let status = envelope.status, !(200..<300).contains(status) {
                throw APIError.from(statusCode: status, responseData: object)
            }
            return envelope.data
                ?? AcceptTermsResponse(fullName: "", email: "", hasAcceptedTerms: true)
        }
        return try JSONDecoder.assinafy.decode(AcceptTermsResponse.self, from: data)
    }

    /// Verifies a signer's email using a verification code.
    ///
    /// - Parameter payload: The verification code and signer access code.
    /// - Throws: ``APIError`` if verification fails.
    public func verifyEmail(payload: VerifyEmailPayload) async throws {
        let code = try requireId(payload.signerAccessCode, name: "Signer access code")
        let request = APIRequest(
            method: .post,
            path: "/verify",
            queryItems: [URLQueryItem(name: "signer-access-code", value: code)],
            body: try JSONEncoder.assinafy.encode(payload)
        )
        try await callVoid("Failed to verify email", request: request)
    }

    /// Uploads a signature or initial image for a signer.
    ///
    /// - Parameters:
    ///   - signerAccessCode: The signer access code from the signing URL.
    ///   - type: The type of image to upload (signature or initial).
    ///   - imageData: PNG image data.
    ///   - reuse: When `true`, marks the uploaded image to be reused for future
    ///     documents (sends `reuse=true`). Defaults to `false`.
    public func uploadSignature(
        signerAccessCode: String,
        type: SignatureType,
        imageData: Data,
        reuse: Bool = false
    ) async throws {
        let code = try requireId(signerAccessCode, name: "Signer access code")
        var items = [
            URLQueryItem(name: "signer-access-code", value: code),
            URLQueryItem(name: "type", value: type.stringValue)
        ]
        if reuse { items.append(.init(name: "reuse", value: "true")) }
        let request = APIRequest(
            method: .post,
            path: "/signature",
            queryItems: items,
            body: imageData,
            contentType: "image/png"
        )
        try await callVoid("Failed to upload signature", request: request)
    }

    /// Downloads a signer's signature or initial image.
    ///
    /// - Parameters:
    ///   - signerAccessCode: The signer access code from the signing URL.
    ///   - type: The type of image to download (signature or initial).
    /// - Returns: The raw image data (PNG).
    public func downloadSignature(
        signerAccessCode: String,
        type: SignatureType
    ) async throws -> Data {
        let code = try requireId(signerAccessCode, name: "Signer access code")
        let items = [URLQueryItem(name: "signer-access-code", value: code)]
        return try await callData("Failed to download signature",
                                  request: .get("/signature/\(type.stringValue)", queryItems: items))
    }

    // MARK: - Signer-facing document endpoints

    /// Retrieves the signer's current document via the access code.
    ///
    /// Mirrors `GET /signers/{signer_id}/document?signer-access-code=...`.
    /// The returned document mirrors the standard ``DocumentDetails`` shape
    /// but omits the `pages` array and filters `assignment.items` to the
    /// current signer's items.
    public func getCurrentDocument(
        signerId: String,
        signerAccessCode: String
    ) async throws -> DocumentDetails {
        let sid = try requireId(signerId, name: "Signer ID")
        let code = try requireId(signerAccessCode, name: "Signer access code")
        return try await call("Failed to fetch signer's current document",
                              request: .get("/signers/\(sid)/document",
                                            queryItems: [URLQueryItem(name: "signer-access-code", value: code)]))
    }

    /// Lists every document the signer has access to with the given access code.
    ///
    /// Mirrors `GET /signers/{signer_id}/documents?signer-access-code=...`.
    public func listSignerDocuments(
        signerId: String,
        signerAccessCode: String,
        params: SignerDocumentListParams = SignerDocumentListParams()
    ) async throws -> PaginatedResult<DocumentDetails> {
        let sid = try requireId(signerId, name: "Signer ID")
        let code = try requireId(signerAccessCode, name: "Signer access code")
        var items = params.toQueryItems()
        items.append(URLQueryItem(name: "signer-access-code", value: code))
        return try await callList(
            "Failed to list signer documents",
            request: .get("/signers/\(sid)/documents", queryItems: items)
        )
    }

    /// Searches the signer's accessible documents (lightweight).
    ///
    /// Mirrors `GET /signers/{signer_id}/documents/search?signer-access-code=...`.
    ///
    /// - Parameters:
    ///   - signerId: The signer identifier.
    ///   - signerAccessCode: The signer access code from the signing URL.
    ///   - search: Free-text search term.
    ///   - status: Legacy server extension retained for compatibility.
    public func searchSignerDocuments(
        signerId: String,
        signerAccessCode: String,
        search: String? = nil,
        status: String? = nil
    ) async throws -> PaginatedResult<DocumentDetails> {
        let sid = try requireId(signerId, name: "Signer ID")
        let code = try requireId(signerAccessCode, name: "Signer access code")
        var items = [URLQueryItem(name: "signer-access-code", value: code)]
        if let search, !search.isEmpty { items.append(.init(name: "search", value: search)) }
        if let status, !status.isEmpty { items.append(.init(name: "status", value: status)) }
        return try await callList(
            "Failed to search signer documents",
            request: .get("/signers/\(sid)/documents/search", queryItems: items)
        )
    }

    /// Signs multiple virtual-method documents in one call.
    ///
    /// Mirrors `PUT /signers/documents/sign-multiple?signer-access-code=...`.
    public func signMultipleDocuments(
        signerAccessCode: String,
        documentIds: [String]
    ) async throws {
        let code = try requireId(signerAccessCode, name: "Signer access code")
        guard !documentIds.isEmpty else {
            throw ValidationError("documentIds must not be empty")
        }
        let payload = SignMultipleDocumentsPayload(documentIds: documentIds)
        let body = try JSONEncoder.assinafy.encode(payload)
        let request = APIRequest(
            method: .put,
            path: "/signers/documents/sign-multiple",
            queryItems: [URLQueryItem(name: "signer-access-code", value: code)],
            body: body
        )
        try await callVoid("Failed to sign multiple documents", request: request)
    }

    /// Declines multiple documents in one call.
    ///
    /// Mirrors `PUT /signers/documents/decline-multiple?signer-access-code=...`.
    public func declineMultipleDocuments(
        signerAccessCode: String,
        documentIds: [String],
        reason: String
    ) async throws {
        let code = try requireId(signerAccessCode, name: "Signer access code")
        guard !documentIds.isEmpty else {
            throw ValidationError("documentIds must not be empty")
        }
        let payload = DeclineMultipleDocumentsPayload(documentIds: documentIds, declineReason: reason)
        let body = try JSONEncoder.assinafy.encode(payload)
        let request = APIRequest(
            method: .put,
            path: "/signers/documents/decline-multiple",
            queryItems: [URLQueryItem(name: "signer-access-code", value: code)],
            body: body
        )
        try await callVoid("Failed to decline multiple documents", request: request)
    }

    /// Downloads a signer document artifact from the documented public endpoint.
    ///
    /// Mirrors `GET /signers/{signer_id}/documents/{document_id}/download/{artifact}`.
    public func downloadSignerDocumentArtifact(
        signerId: String,
        documentId: String,
        artifact: DocumentArtifactName
    ) async throws -> Data {
        let sid = try requireId(signerId, name: "Signer ID")
        let did = try requireId(documentId, name: "Document ID")
        return try await callData(
            "Failed to download signer document artifact",
            request: .get("/signers/\(sid)/documents/\(did)/download/\(artifact.pathValue)")
        )
    }

    /// Compatibility overload. The access code is no longer sent because this
    /// endpoint is unauthenticated in the current API contract.
    public func downloadSignerDocumentArtifact(
        signerId: String,
        documentId: String,
        artifact: DocumentArtifactName,
        signerAccessCode: String
    ) async throws -> Data {
        _ = signerAccessCode
        return try await downloadSignerDocumentArtifact(
            signerId: signerId,
            documentId: documentId,
            artifact: artifact
        )
    }

    /// Retrieves document assignment details from the generic signer endpoint.
    ///
    /// Mirrors `GET /sign?signer-access-code=...`. This is useful when a
    /// signing URL carries only an access code and not a signer ID.
    public func getSigningDocument(
        signerAccessCode: String,
        hasAcceptedTerms: Bool? = nil
    ) async throws -> DocumentDetails {
        let code = try requireId(signerAccessCode, name: "Signer access code")
        var items = [URLQueryItem(name: "signer-access-code", value: code)]
        if let hasAcceptedTerms {
            items.append(.init(name: "has_accepted_terms", value: hasAcceptedTerms ? "true" : "false"))
        }
        return try await call(
            "Failed to fetch signing document",
            request: .get("/sign", queryItems: items)
        )
    }

    // MARK: - Objective-C / completion-handler API

    /// Creates a signer and delivers the result on the **main queue**.
    ///
    /// ```objc
    /// [client.signers createWithPayload:payload accountId:nil
    ///     completion:^(Signer *signer, NSError *error) {
    ///         // runs on main thread
    /// }];
    /// ```
    @objc(createSigner:accountId:completion:)
    public func create(
        _ payload: CreateSignerPayload,
        accountId: String?,
        completion: @escaping (Signer?, Error?) -> Void
    ) {
        withCompletion({ try await self.create(payload, accountId: accountId) }, completion: completion)
    }

    /// Fetches a signer by ID and delivers the result on the **main queue**.
    @objc(getSignerWithId:accountId:completion:)
    public func get(
        signerId: String,
        accountId: String?,
        completion: @escaping (Signer?, Error?) -> Void
    ) {
        withCompletion({ try await self.get(signerId: signerId, accountId: accountId) }, completion: completion)
    }

    /// Updates a signer and delivers the result on the **main queue**.
    @objc(updateSignerWithId:payload:accountId:completion:)
    public func update(
        signerId: String,
        payload: UpdateSignerPayload,
        accountId: String?,
        completion: @escaping (Signer?, Error?) -> Void
    ) {
        withCompletion({ try await self.update(signerId: signerId, payload: payload, accountId: accountId) }, completion: completion)
    }

    /// Deletes a signer and notifies the **main queue** upon completion.
    @objc(deleteSignerWithId:accountId:completion:)
    public func delete(
        signerId: String,
        accountId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.delete(signerId: signerId, accountId: accountId) }, completion: completion)
    }

    /// Finds a signer by email and delivers the result on the **main queue**.
    @objc(findSignerByEmail:accountId:completion:)
    public func findByEmail(
        _ email: String,
        accountId: String?,
        completion: @escaping (Signer?, Error?) -> Void
    ) {
        withOptionalCompletion({ try await self.findByEmail(email, accountId: accountId) }, completion: completion)
    }

    // MARK: - Private

    /// Validates signer input without performing network I/O.
    ///
    /// Internal workflows use this before creating prerequisite resources so
    /// invalid signer input cannot leave those resources orphaned.
    func validateCreatePayload(_ payload: CreateSignerPayload) throws {
        guard !payload.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Signer full name is required")
        }
        if let email = payload.email {
            try assertValidEmail(email)
        }
    }

    private func assertValidEmail(_ email: String) throws {
        guard !email.isEmpty,
              email.range(of: emailPattern, options: .regularExpression)
                == email.startIndex..<email.endIndex else {
            throw ValidationError("Invalid email address", errors: ["email": email])
        }
    }
}
