import Foundation

/// Sends and manages groups of documents. Access through AssinafyClient.envelopes.
/// Creation requires the Envelopes feature; OAuth uses documents:read or documents:write.
@objcMembers
public final class EnvelopeResource: BaseResource, @unchecked Sendable {
    private func path(_ accountId: String?, _ envelopeId: String? = nil) throws -> String {
        let base = "/accounts/\(try self.accountId(accountId))/envelopes"
        guard let envelopeId else { return base }
        return base + "/" + (try requireId(envelopeId, name: "Envelope ID"))
    }

    /// Mirrors `GET /accounts/{accountId}/envelopes`. Search and paginate open or closed groups.
    public func list(params: ListParams = ListParams(), status: String? = nil, accountId: String? = nil) async throws -> PaginatedResult<DocumentEnvelope> {
        var query = params.toQueryItems()
        if let status {
            guard ["open", "closed"].contains(status) else { throw ValidationError("Envelope status must be open or closed") }
            query.append(URLQueryItem(name: "status", value: status))
        }
        return try await callList("Failed to list envelopes", request: .get(path(accountId), queryItems: query))
    }

    /// Delivers the result on the main queue.
    public func list(query: [String: String], status: String?, accountId: String?, completion: @escaping ([DocumentEnvelope]?, Error?) -> Void) {
        withListCompletion({ try await self.list(params: ListParams(extra: query), status: status, accountId: accountId) }, completion: completion)
    }

    /// Mirrors `GET /accounts/{accountId}/envelopes/{envelopeId}`.
    public func get(envelopeId: String, accountId: String? = nil) async throws -> DocumentEnvelope {
        try await call("Failed to fetch envelope", request: .get(path(accountId, envelopeId)))
    }

    /// Delivers the result on the main queue.
    public func get(envelopeId: String, accountId: String?, completion: @escaping (DocumentEnvelope?, Error?) -> Void) {
        withCompletion({ try await self.get(envelopeId: envelopeId, accountId: accountId) }, completion: completion)
    }

    /// Mirrors `POST /accounts/{accountId}/envelopes`. Sends one invitation per signer; retain the idempotency key after an uncertain result.
    public func create(payload: CreateEnvelopePayload, idempotencyKey: String? = nil, accountId: String? = nil) async throws -> DocumentEnvelope {
        let request = try APIRequest.post(path(accountId), body: payload).withIdempotencyKey(idempotencyKey)
        return try await call("Failed to create envelope", request: request)
    }

    /// Delivers the result on the main queue.
    public func create(payloadJSON: Data, idempotencyKey: String?, accountId: String?, completion: @escaping (DocumentEnvelope?, Error?) -> Void) {
        withCompletion({ try await self.create(payload: CreateEnvelopePayload(jsonData: payloadJSON), idempotencyKey: idempotencyKey, accountId: accountId) }, completion: completion)
    }

    /// Mirrors `POST /accounts/{accountId}/envelopes/estimate-cost`. Does not create, notify or charge.
    public func estimateCost(payload: CreateEnvelopePayload, accountId: String? = nil) async throws -> CostEstimate {
        try await call("Failed to estimate envelope", request: .post(path(accountId) + "/estimate-cost", body: payload))
    }

    /// Delivers the result on the main queue.
    public func estimateCost(payloadJSON: Data, accountId: String?, completion: @escaping (CostEstimate?, Error?) -> Void) {
        withCompletion({ try await self.estimateCost(payload: CreateEnvelopePayload(jsonData: payloadJSON), accountId: accountId) }, completion: completion)
    }

    /// Mirrors `PATCH /accounts/{accountId}/envelopes/{envelopeId}`. Changes name, message or full document order without sending notifications.
    public func update(envelopeId: String, payload: UpdateEnvelopePayload, accountId: String? = nil) async throws -> DocumentEnvelope {
        try await call("Failed to update envelope", request: .patch(path(accountId, envelopeId), body: payload))
    }

    /// Delivers the result on the main queue.
    public func update(envelopeId: String, payload: UpdateEnvelopePayload, accountId: String?, completion: @escaping (DocumentEnvelope?, Error?) -> Void) {
        withCompletion({ try await self.update(envelopeId: envelopeId, payload: payload, accountId: accountId) }, completion: completion)
    }

    /// Mirrors `DELETE /accounts/{accountId}/envelopes/{envelopeId}`. Requires every document closed; documents remain accessible individually.
    public func delete(envelopeId: String, accountId: String? = nil) async throws {
        try await callVoid("Failed to delete envelope", request: .delete(path(accountId, envelopeId)))
    }

    /// Delivers the result on the main queue.
    public func delete(envelopeId: String, accountId: String?, completion: @escaping (Error?) -> Void) {
        withVoidCompletion({ try await self.delete(envelopeId: envelopeId, accountId: accountId) }, completion: completion)
    }

    /// Mirrors `PUT /accounts/{accountId}/envelopes/{envelopeId}/cancel`. Cancels eligible documents and notifies their recipients.
    public func cancel(envelopeId: String, accountId: String? = nil) async throws -> [EnvelopeCancellation] {
        try await call("Failed to cancel envelope", request: .put(path(accountId, envelopeId) + "/cancel"))
    }

    /// Delivers the result on the main queue.
    public func cancel(envelopeId: String, accountId: String?, completion: @escaping ([EnvelopeCancellation]?, Error?) -> Void) {
        withCompletion({ try await self.cancel(envelopeId: envelopeId, accountId: accountId) }, completion: completion)
    }

    /// Mirrors `PUT /accounts/{accountId}/envelopes/{envelopeId}/signers/{signerId}/resend`. Paid channels charge once per message.
    public func resendNotification(envelopeId: String, signerId: String, accountId: String? = nil) async throws -> ResendNotificationResponse {
        let sid = try requireId(signerId, name: "Signer ID")
        return try await call("Failed to remind envelope signer", request: .put(path(accountId, envelopeId) + "/signers/\(sid)/resend"))
    }

    /// Delivers the result on the main queue.
    public func resendNotification(envelopeId: String, signerId: String, accountId: String?, completion: @escaping (ResendNotificationResponse?, Error?) -> Void) {
        withCompletion({ try await self.resendNotification(envelopeId: envelopeId, signerId: signerId, accountId: accountId) }, completion: completion)
    }

    /// Mirrors `POST /accounts/{accountId}/envelopes/{envelopeId}/documents`. Uses existing envelope signers and sends their invitation again.
    public func addDocument(envelopeId: String, payload: EnvelopeDocumentPayload, accountId: String? = nil) async throws -> DocumentEnvelope {
        try await call("Failed to add envelope document", request: .post(path(accountId, envelopeId) + "/documents", body: payload))
    }

    /// Delivers the result on the main queue.
    public func addDocument(envelopeId: String, payloadJSON: Data, accountId: String?, completion: @escaping (DocumentEnvelope?, Error?) -> Void) {
        withCompletion({ try await self.addDocument(envelopeId: envelopeId, payload: EnvelopeDocumentPayload(jsonData: payloadJSON), accountId: accountId) }, completion: completion)
    }

    /// Mirrors `DELETE /accounts/{accountId}/envelopes/{envelopeId}/documents/{documentId}`. Cancels the open document and notifies its recipients.
    public func removeDocument(envelopeId: String, documentId: String, accountId: String? = nil) async throws -> DocumentEnvelope {
        let did = try requireId(documentId, name: "Document ID")
        return try await call("Failed to remove envelope document", request: .delete(path(accountId, envelopeId) + "/documents/\(did)"))
    }

    /// Delivers the result on the main queue.
    public func removeDocument(envelopeId: String, documentId: String, accountId: String?, completion: @escaping (DocumentEnvelope?, Error?) -> Void) {
        withCompletion({ try await self.removeDocument(envelopeId: envelopeId, documentId: documentId, accountId: accountId) }, completion: completion)
    }

    /// Mirrors `GET /accounts/{accountId}/envelopes/{envelopeId}/activities`. Includes document IDs and names; paginate with page/per-page.
    public func activities(envelopeId: String, params: ListParams = ListParams(), accountId: String? = nil) async throws -> PaginatedResult<DocumentActivity> {
        try await callList("Failed to fetch envelope activities", request: .get(path(accountId, envelopeId) + "/activities", queryItems: params.toQueryItems()))
    }

    /// Delivers the result on the main queue.
    public func activities(envelopeId: String, query: [String: String], accountId: String?, completion: @escaping ([DocumentActivity]?, Error?) -> Void) {
        withListCompletion({ try await self.activities(envelopeId: envelopeId, params: ListParams(extra: query), accountId: accountId) }, completion: completion)
    }

    /// Mirrors `GET /accounts/{accountId}/envelopes/{envelopeId}/download/{artifactName}`. Returns ZIP bytes; certified artifacts include only completed documents.
    public func download(envelopeId: String, artifact: DocumentArtifactName = .original, accountId: String? = nil) async throws -> Data {
        try await callData("Failed to download envelope", request: .get(path(accountId, envelopeId) + "/download/\(artifact.pathValue)"))
    }

    /// Delivers the result on the main queue.
    public func download(envelopeId: String, artifact: DocumentArtifactName, accountId: String?, completion: @escaping (Data?, Error?) -> Void) {
        withCompletion({ try await self.download(envelopeId: envelopeId, artifact: artifact, accountId: accountId) }, completion: completion)
    }

}
