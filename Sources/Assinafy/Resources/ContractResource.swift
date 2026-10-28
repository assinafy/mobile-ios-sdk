import Foundation

/// Tracks contract terms and their amendment, renewal, and termination documents.
/// Access through ``AssinafyClient/contracts``. All routes use the workspace credential.
@objcMembers
public final class ContractResource: BaseResource, @unchecked Sendable {
    /// Mirrors `GET /accounts/{accountId}/contracts`.
    /// Returns a page of root contracts, newest change first by default. Use pagination
    /// and `updatedAt` to recover changes missed by webhook delivery.
    /// - Parameters:
    ///   - params: Optional filters, expansion, sorting, and pagination.
    ///   - accountId: Override the client's default workspace.
    /// - Returns: Contracts and the response's pagination metadata.
    public func list(
        params: ContractListParams = ContractListParams(), accountId: String? = nil
    ) async throws -> PaginatedResult<DocumentContract> {
        let id = try self.accountId(accountId)
        let items = try params.toQueryItems()
        return try await callList("Failed to list contracts", request: .get(
            "/accounts/\(id)/contracts", queryItems: items.isEmpty ? nil : items
        ))
    }

    /// Mirrors `GET /accounts/{accountId}/documents/{documentId}/contract`.
    /// Reads either the document's root terms and amendments, or its own amendment link.
    /// Existing terms remain readable when the workspace's plan no longer includes tracking.
    /// - Parameters:
    ///   - documentId: Document carrying terms or an amendment link.
    ///   - accountId: Override the client's default workspace.
    /// - Returns: Root terms or an amendment; `404 NoContractTerms` when neither exists.
    public func get(documentId: String, accountId: String? = nil) async throws -> ContractDetails {
        try await call("Failed to fetch contract", request: .get(path(documentId, accountId)))
    }

    /// Mirrors `PUT /accounts/{accountId}/documents/{documentId}/contract`.
    /// Creates terms or changes only supplied fields. A parent document links this document
    /// as an instrument whose delta applies on certification; applied links are read-only.
    /// - Parameters:
    ///   - documentId: Document whose terms or link should change.
    ///   - payload: Partial fields, explicit nulls, and optional `updated_at` precondition.
    ///   - accountId: Override the client's default workspace.
    /// - Returns: Saved terms or amendment link. `409` preserves concurrent changes.
    public func update(
        documentId: String, payload: UpdateContractPayload, accountId: String? = nil
    ) async throws -> ContractDetails {
        let request = try APIRequest.put(path(documentId, accountId), body: payload)
        return try await call("Failed to update contract", request: request)
    }

    /// Mirrors `GET /accounts/{accountId}/documents/{documentId}/contract/related`.
    /// Resolves either a root document or any linked instrument to the root and its family.
    /// - Parameters:
    ///   - documentId: Any document in the contract family.
    ///   - accountId: Override the client's default workspace.
    /// - Returns: Root contract with its amendments; `404 NoContractTerms` when none exists.
    public func related(documentId: String, accountId: String? = nil) async throws -> DocumentContract {
        try await call("Failed to fetch contract family", request: .get(path(documentId, accountId) + "/related"))
    }

    /// Mirrors `POST /accounts/{accountId}/documents/{documentId}/contract/renew`.
    /// Advances the term and end date, optionally replacing the value. The current term
    /// or explicit new end date guards against duplicate renewal; the SDK does not retry.
    /// - Parameters:
    ///   - documentId: Root contract document.
    ///   - payload: Current term or new end date, optional value and concurrency precondition.
    ///   - accountId: Override the client's default workspace.
    /// - Returns: Renewed contract. Expired contracts reopen; terminated contracts return `400`.
    public func renew(
        documentId: String, payload: RenewContractPayload, accountId: String? = nil
    ) async throws -> DocumentContract {
        let request = try APIRequest.post(path(documentId, accountId) + "/renew", body: payload)
        return try await call("Failed to renew contract", request: request)
    }

    /// Mirrors `POST /accounts/{accountId}/documents/{documentId}/contract/terminate`.
    /// Sets the contract status to terminated and stops lifecycle alerts.
    /// - Parameters:
    ///   - documentId: Root contract document.
    ///   - payload: Optional event reason and last-read timestamp.
    ///   - accountId: Override the client's default workspace.
    /// - Returns: Terminated contract; `409` when its supplied timestamp is stale.
    public func terminate(
        documentId: String, payload: TerminateContractPayload = TerminateContractPayload(),
        accountId: String? = nil
    ) async throws -> DocumentContract {
        guard (payload.reason?.unicodeScalars.count ?? 0) <= 500 else {
            throw ValidationError("Contract termination reason must not exceed 500 characters")
        }
        let request = try APIRequest.post(path(documentId, accountId) + "/terminate", body: payload)
        return try await call("Failed to terminate contract", request: request)
    }

    private func path(_ documentId: String, _ accountId: String?) throws -> String {
        let id = try self.accountId(accountId)
        let document = try requireId(documentId, name: "Document ID")
        return "/accounts/\(id)/documents/\(document)/contract"
    }

    /// Lists contracts and delivers the items on the main queue.
    @objc(listContractsWithParams:accountId:completion:)
    public func list(params: ContractListParams, accountId: String?,
                     completion: @escaping ([DocumentContract]?, Error?) -> Void) {
        withListCompletion({ try await self.list(params: params, accountId: accountId) }, completion: completion)
    }

    /// Reads terms or an amendment and delivers the result on the main queue.
    @objc(getContractWithDocumentId:accountId:completion:)
    public func get(documentId: String, accountId: String?, completion: @escaping (ContractDetails?, Error?) -> Void) {
        withCompletion({ try await self.get(documentId: documentId, accountId: accountId) }, completion: completion)
    }

    /// Updates terms or an amendment and delivers the result on the main queue.
    @objc(updateContractWithDocumentId:payload:accountId:completion:)
    public func update(documentId: String, payload: UpdateContractPayload, accountId: String?,
                       completion: @escaping (ContractDetails?, Error?) -> Void) {
        withCompletion({ try await self.update(documentId: documentId, payload: payload, accountId: accountId) }, completion: completion)
    }

    /// Reads the root contract family and delivers it on the main queue.
    @objc(relatedContractWithDocumentId:accountId:completion:)
    public func related(documentId: String, accountId: String?, completion: @escaping (DocumentContract?, Error?) -> Void) {
        withCompletion({ try await self.related(documentId: documentId, accountId: accountId) }, completion: completion)
    }

    /// Renews a contract and delivers it on the main queue.
    @objc(renewContractWithDocumentId:payload:accountId:completion:)
    public func renew(documentId: String, payload: RenewContractPayload, accountId: String?,
                      completion: @escaping (DocumentContract?, Error?) -> Void) {
        withCompletion({ try await self.renew(documentId: documentId, payload: payload, accountId: accountId) }, completion: completion)
    }

    /// Terminates a contract and delivers it on the main queue.
    @objc(terminateContractWithDocumentId:payload:accountId:completion:)
    public func terminate(documentId: String, payload: TerminateContractPayload, accountId: String?,
                          completion: @escaping (DocumentContract?, Error?) -> Void) {
        withCompletion({ try await self.terminate(documentId: documentId, payload: payload, accountId: accountId) }, completion: completion)
    }
}
