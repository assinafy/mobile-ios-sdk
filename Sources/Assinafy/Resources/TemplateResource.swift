import Foundation

/// Provides read access to reusable document templates.
///
/// Access this resource through ``AssinafyClient/templates``.
///
/// ## Example
/// ```swift
/// let templates = try await client.templates.list(accountId: "acc_id")
/// ```
@objcMembers
public final class TemplateResource: BaseResource {

    // MARK: - Swift async API

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
}
