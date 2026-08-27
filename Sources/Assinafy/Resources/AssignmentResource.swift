import Foundation

/// Manages signing assignments that link documents to signers.
///
/// Access this resource through ``AssinafyClient/assignments``.
///
/// ## Example
/// ```swift
/// let assignment = try await client.assignments.create(
///     documentId: "doc_id",
///     payload: .withSignerIds(["signer_id"])
/// )
/// ```
@objcMembers
public final class AssignmentResource: BaseResource, @unchecked Sendable {

    // MARK: - Swift async API

    /// Lists assignments for the authenticated user's current account.
    ///
    /// Mirrors `GET /assignments`. Production derives account context from the
    /// credentials. An explicitly supplied `accountId` is retained for legacy
    /// deployments; clients configured for the Assinafy sandbox add their default
    /// account because that host requires the compatibility query.
    ///
    /// - Parameters:
    ///   - params: Pagination parameters (`page`, `per-page`).
    ///   - accountId: Explicit account identifier for deployments that require it.
    /// - Returns: A ``PaginatedResult`` of ``Assignment`` objects.
    public func list(
        params: ListParams = ListParams(),
        accountId: String? = nil
    ) async throws -> PaginatedResult<Assignment> {
        var items = params.toQueryItems()
        if let accountId = accountId ?? (usesSandboxCompatibility ? defaultAccountId : nil) {
            items.append(URLQueryItem(
                name: "accountId",
                value: try requireId(accountId, name: "Account ID")
            ))
        }
        return try await callList(
            "Failed to list assignments",
            request: .get("/assignments", queryItems: items.isEmpty ? nil : items)
        )
    }

    /// Creates a signing assignment for a document.
    ///
    /// - Parameters:
    ///   - documentId: The document to assign.
    ///   - payload: Signing method, signers, message, and optional expiry.
    /// - Returns: The created ``Assignment``.
    public func create(
        documentId: String,
        payload: CreateAssignmentPayload
    ) async throws -> Assignment {
        let did = try requireId(documentId, name: "Document ID")
        let body = try buildAssignmentBody(payload)
        let request = try APIRequest.post("/documents/\(did)/assignments", body: body)
        return try await call("Failed to create assignment", request: request)
    }

    /// Estimates the cost of an assignment before creating it.
    ///
    /// Useful for displaying price breakdowns before confirming with the user.
    ///
    /// - Parameters:
    ///   - documentId: The document to estimate for.
    ///   - payload: The proposed assignment configuration.
    /// - Returns: A ``CostEstimate`` containing the price breakdown.
    public func estimateCost(
        documentId: String,
        payload: CreateAssignmentPayload
    ) async throws -> CostEstimate {
        let did = try requireId(documentId, name: "Document ID")
        let body = try buildAssignmentEstimateBody(payload)
        let request = try APIRequest.post("/documents/\(did)/assignments/estimate-cost", body: body)
        return try await call("Failed to estimate assignment cost", request: request)
    }

    /// Resets the expiration date on an existing assignment.
    ///
    /// - Parameters:
    ///   - documentId: The document ID.
    ///   - assignmentId: The assignment ID to reset.
    ///   - expiresAt: New expiration date, or `nil` to remove the expiration.
    /// - Returns: The updated ``Assignment``.
    public func resetExpiration(
        documentId: String,
        assignmentId: String,
        expiresAt: String? = nil
    ) async throws -> Assignment {
        let did = try requireId(documentId, name: "Document ID")
        let aid = try requireId(assignmentId, name: "Assignment ID")
        let request = try APIRequest.put(
            "/documents/\(did)/assignments/\(aid)/reset-expiration",
            body: ResetExpirationPayload(expiresAt: expiresAt)
        )
        return try await call("Failed to reset assignment expiration", request: request)
    }

    /// Sets a non-null expiration date using the current API contract.
    public func resetExpiration(
        documentId: String,
        assignmentId: String,
        newExpiresAt: String
    ) async throws -> Assignment {
        guard !newExpiresAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Expiration date is required")
        }
        return try await resetExpiration(
            documentId: documentId,
            assignmentId: assignmentId,
            expiresAt: newExpiresAt
        )
    }

    /// Resends a signing notification to one pending signer.
    ///
    /// - Parameters:
    ///   - documentId: The document ID.
    ///   - assignmentId: The assignment ID.
    ///   - signerId: The signer who should receive the new notification.
    /// - Returns: A ``ResendNotificationResponse`` confirming delivery.
    public func resendNotification(
        documentId: String,
        assignmentId: String,
        signerId: String
    ) async throws -> ResendNotificationResponse {
        let did = try requireId(documentId, name: "Document ID")
        let aid = try requireId(assignmentId, name: "Assignment ID")
        let sid = try requireId(signerId, name: "Signer ID")
        let request = APIRequest.put(
            "/documents/\(did)/assignments/\(aid)/signers/\(sid)/resend"
        )
        return try await call("Failed to resend notification", request: request)
    }

    /// Estimates the cost of resending a notification to one signer.
    ///
    /// - Parameters:
    ///   - documentId: The document ID.
    ///   - assignmentId: The assignment ID.
    ///   - signerId: The signer who would receive the notification.
    /// - Returns: A ``CostEstimate`` with the resend cost breakdown.
    public func estimateResendCost(
        documentId: String,
        assignmentId: String,
        signerId: String
    ) async throws -> CostEstimate {
        let did = try requireId(documentId, name: "Document ID")
        let aid = try requireId(assignmentId, name: "Assignment ID")
        let sid = try requireId(signerId, name: "Signer ID")
        let request = APIRequest.post(
            "/documents/\(did)/assignments/\(aid)/signers/\(sid)/estimate-resend-cost"
        )
        return try await call("Failed to estimate resend cost", request: request)
    }

    /// Signs an assignment on behalf of the signer (collect or virtual).
    ///
    /// Mirrors `POST /documents/{documentId}/assignments/{assignmentId}`.
    ///
    /// For **virtual** assignments, ``DocumentResource/confirmSignerData(documentId:signerAccessCode:payload:)``
    /// must be called first or the API responds with a `400` error
    /// (`"Signer data must be confirmed before signing."`).
    ///
    /// - Parameters:
    ///   - documentId: The document ID.
    ///   - assignmentId: The assignment ID.
    ///   - signerAccessCode: The signer access code from the signing URL.
    ///   - fields: Array of signed field placements; pass an empty array for
    ///     virtual assignments without input fields.
    public func sign(
        documentId: String,
        assignmentId: String,
        signerAccessCode: String,
        fields: [SignAssignmentField] = []
    ) async throws {
        let did = try requireId(documentId, name: "Document ID")
        let aid = try requireId(assignmentId, name: "Assignment ID")
        let code = try requireId(signerAccessCode, name: "Signer access code")
        for field in fields {
            _ = try requireId(field.itemId, name: "Assignment item ID")
            _ = try requireId(field.fieldId, name: "Field ID")
            _ = try requireId(field.pageId, name: "Page ID")
        }
        let body = try JSONEncoder.assinafy.encode(fields)
        let request = APIRequest(
            method: .post,
            path: "/documents/\(did)/assignments/\(aid)",
            queryItems: [URLQueryItem(name: "signer-access-code", value: code)],
            body: body,
            credential: .withheld
        )
        try await callVoid("Failed to sign assignment", request: request)
    }

    /// Declines (rejects) an assignment on behalf of the signer.
    ///
    /// Mirrors `PUT /documents/{documentId}/assignments/{assignmentId}/reject`.
    ///
    /// - Parameters:
    ///   - documentId: The document ID.
    ///   - assignmentId: The assignment ID.
    ///   - signerAccessCode: The signer access code from the signing URL.
    ///   - reason: Descriptive reason for declining the invitation.
    public func decline(
        documentId: String,
        assignmentId: String,
        signerAccessCode: String,
        reason: String
    ) async throws {
        let did = try requireId(documentId, name: "Document ID")
        let aid = try requireId(assignmentId, name: "Assignment ID")
        let code = try requireId(signerAccessCode, name: "Signer access code")
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Decline reason is required")
        }
        let payload = DeclineAssignmentPayload(declineReason: reason)
        let body = try JSONEncoder.assinafy.encode(payload)
        let request = APIRequest(
            method: .put,
            path: "/documents/\(did)/assignments/\(aid)/reject",
            queryItems: [URLQueryItem(name: "signer-access-code", value: code)],
            body: body,
            credential: .withheld
        )
        try await callVoid("Failed to decline assignment", request: request)
    }

    /// Lists WhatsApp notification messages dispatched for an assignment.
    ///
    /// Mirrors `GET /documents/{documentId}/assignments/{assignmentId}/whatsapp-notifications`.
    public func listWhatsappNotifications(
        documentId: String,
        assignmentId: String
    ) async throws -> [WhatsappNotification] {
        let did = try requireId(documentId, name: "Document ID")
        let aid = try requireId(assignmentId, name: "Assignment ID")
        let result: PaginatedResult<WhatsappNotification> = try await callList(
            "Failed to list WhatsApp notifications",
            request: .get("/documents/\(did)/assignments/\(aid)/whatsapp-notifications")
        )
        return result.data
    }

    // MARK: - Objective-C / completion-handler API

    /// Lists assignments and delivers the result on the **main queue**.
    @objc(listAssignmentsWithAccountId:completion:)
    public func list(
        accountId: String?,
        completion: @escaping ([Assignment]?, Error?) -> Void
    ) {
        withListCompletion({ try await self.list(accountId: accountId) }, completion: completion)
    }

    /// Creates an assignment and delivers the result on the **main queue**.
    @objc(createAssignmentForDocument:signerIds:completion:)
    public func create(
        documentId: String,
        signerIds: [String],
        completion: @escaping (Assignment?, Error?) -> Void
    ) {
        let payload = CreateAssignmentPayload.withSignerIds(signerIds)
        withCompletion({ try await self.create(documentId: documentId, payload: payload) }, completion: completion)
    }

    /// Resends a notification and delivers the result on the **main queue**.
    @objc(resendNotificationForDocument:assignmentId:signerId:completion:)
    public func resendNotification(
        documentId: String,
        assignmentId: String,
        signerId: String,
        completion: @escaping (ResendNotificationResponse?, Error?) -> Void
    ) {
        withCompletion({
            try await self.resendNotification(documentId: documentId, assignmentId: assignmentId, signerId: signerId)
        }, completion: completion)
    }
}

private struct ResetExpirationPayload: Encodable {
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case expiresAt = "expires_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(expiresAt, forKey: .expiresAt)
    }
}
