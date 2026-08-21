import Foundation

/// Manages workspace (account) objects.
///
/// Access this resource through ``AssinafyClient/workspaces``.
///
/// ## Example
/// ```swift
/// let workspace = try await client.workspaces.create(
///     CreateWorkspacePayload(name: "Acme Corp")
/// )
/// ```
@objcMembers
public final class WorkspaceResource: BaseResource {

    // MARK: - Swift async API

    /// Creates a new workspace.
    ///
    /// - Parameter payload: Name and branding options for the workspace.
    /// - Returns: The created ``WorkspaceResponse``.
    public func create(_ payload: CreateWorkspacePayload) async throws -> WorkspaceResponse {
        let request = try APIRequest.post("/accounts", body: payload)
        return try await call("Failed to create workspace", request: request)
    }

    /// Lists all workspaces accessible to the authenticated user.
    ///
    /// The current API accepts no query parameters. `params` remains in the
    /// signature for source compatibility and is not sent.
    ///
    /// - Parameter params: Retained for source compatibility.
    /// - Returns: A ``PaginatedResult`` of ``WorkspaceListItem`` objects.
    public func list(params: ListParams = ListParams()) async throws -> PaginatedResult<WorkspaceListItem> {
        _ = params
        return try await callList("Failed to list workspaces", request: .get("/accounts"))
    }

    /// Fetches a workspace by its ID.
    ///
    /// - Parameter workspaceId: The workspace identifier.
    /// - Returns: The matching ``WorkspaceResponse``.
    public func get(workspaceId: String) async throws -> WorkspaceResponse {
        let wid = try requireId(workspaceId, name: "Workspace ID")
        return try await call("Failed to fetch workspace", request: .get("/accounts/\(wid)"))
    }

    /// Updates a workspace's name or branding colours.
    ///
    /// - Parameters:
    ///   - workspaceId: The workspace identifier.
    ///   - payload: Fields to change.
    /// - Returns: The updated ``WorkspaceResponse``.
    public func update(
        workspaceId: String,
        payload: UpdateWorkspacePayload
    ) async throws -> WorkspaceResponse {
        let wid = try requireId(workspaceId, name: "Workspace ID")
        let request = try APIRequest.put("/accounts/\(wid)", body: payload)
        return try await call("Failed to update workspace", request: request)
    }

    /// Deletes a workspace permanently.
    ///
    /// > Warning: This action is irreversible. All documents, signers, and assignments
    /// > within the workspace are also deleted.
    ///
    /// - Parameters:
    ///   - workspaceId: The workspace identifier.
    ///   - force: When `true`, forces deletion even when the workspace still has
    ///     dependent resources. Sent as the `{ "force": true }` request body.
    public func delete(workspaceId: String, force: Bool = false) async throws {
        let wid = try requireId(workspaceId, name: "Workspace ID")
        let request = try APIRequest.delete("/accounts/\(wid)", body: ["force": force])
        try await callVoid("Failed to delete workspace", request: request)
    }

    /// Fetches the account's branding theme (name, colours, and logo URL).
    ///
    /// This is the canonical source of an account's branding colours.
    ///
    /// - Parameter accountId: Override the client's default account ID.
    /// - Returns: The account's ``AccountTheme``.
    public func theme(accountId: String? = nil) async throws -> AccountTheme {
        let id = try self.accountId(accountId)
        return try await call("Failed to fetch account theme", request: .get("/accounts/\(id)/theme"))
    }

    /// Fetches precomputed per-account document-funnel KPIs.
    ///
    /// - Note: This endpoint is not available on the sandbox host and returns
    ///   `404` there; it is served on production only.
    ///
    /// - Parameters:
    ///   - params: Granularity (`monthly`/`daily`) and month filter.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: A zero-filled series of ``DocumentStatsRow`` values, most recent first.
    public func stats(
        params: AccountStatsParams = AccountStatsParams(),
        accountId: String? = nil
    ) async throws -> [DocumentStatsRow] {
        let id = try self.accountId(accountId)
        let items = params.toQueryItems()
        let result: PaginatedResult<DocumentStatsRow> = try await callList(
            "Failed to fetch account stats",
            request: .get("/accounts/\(id)/stats", queryItems: items.isEmpty ? nil : items)
        )
        return result.data
    }

    /// Downloads the account logo image bytes.
    ///
    /// - Parameter accountId: Override the client's default account ID.
    /// - Returns: The raw image data (throws ``APIError`` with status `404` when no logo is set).
    public func downloadLogo(accountId: String? = nil) async throws -> Data {
        let id = try self.accountId(accountId)
        return try await callData("Failed to download account logo", request: .get("/accounts/\(id)/logo"))
    }

    /// Uploads (replaces) the account logo image.
    ///
    /// - Parameters:
    ///   - imageData: The raw image bytes.
    ///   - filename: The filename sent in the multipart part. Defaults to `logo.png`.
    ///   - contentType: The image MIME type. Defaults to `image/png`.
    ///   - accountId: Override the client's default account ID.
    public func uploadLogo(
        _ imageData: Data,
        filename: String = "logo.png",
        contentType: String = "image/png",
        accountId: String? = nil
    ) async throws {
        let id = try self.accountId(accountId)
        var form = MultipartFormData()
        form.addFile(name: "file", filename: filename, contentType: contentType, data: imageData)
        let request = APIRequest(
            method: .post,
            path: "/accounts/\(id)/logo",
            body: form.finalized(),
            contentType: form.contentType
        )
        try await callVoid("Failed to upload account logo", request: request)
    }

    /// Deletes the account logo.
    ///
    /// - Parameter accountId: Override the client's default account ID.
    public func deleteLogo(accountId: String? = nil) async throws {
        let id = try self.accountId(accountId)
        try await callVoid("Failed to delete account logo", request: .delete("/accounts/\(id)/logo"))
    }

    // MARK: - Objective-C / completion-handler API

    /// Creates a workspace and delivers the result on the **main queue**.
    @objc(createWorkspace:completion:)
    public func create(
        _ payload: CreateWorkspacePayload,
        completion: @escaping (WorkspaceResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.create(payload) }, completion: completion)
    }

    /// Lists workspaces and delivers the result on the **main queue**.
    @objc(listWorkspacesWithCompletion:)
    public func list(completion: @escaping ([WorkspaceListItem]?, Error?) -> Void) {
        withListCompletion({ try await self.list() }, completion: completion)
    }

    /// Fetches a workspace by ID and delivers the result on the **main queue**.
    @objc(getWorkspaceWithId:completion:)
    public func get(
        workspaceId: String,
        completion: @escaping (WorkspaceResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.get(workspaceId: workspaceId) }, completion: completion)
    }

    /// Updates a workspace and delivers the result on the **main queue**.
    @objc(updateWorkspaceWithId:payload:completion:)
    public func update(
        workspaceId: String,
        payload: UpdateWorkspacePayload,
        completion: @escaping (WorkspaceResponse?, Error?) -> Void
    ) {
        withCompletion({ try await self.update(workspaceId: workspaceId, payload: payload) }, completion: completion)
    }

    /// Deletes a workspace and notifies the **main queue** upon completion.
    @objc(deleteWorkspaceWithId:force:completion:)
    public func delete(
        workspaceId: String,
        force: Bool,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.delete(workspaceId: workspaceId, force: force) }, completion: completion)
    }

    /// Fetches the account theme and delivers the result on the **main queue**.
    @objc(themeWithAccountId:completion:)
    public func theme(
        accountId: String?,
        completion: @escaping (AccountTheme?, Error?) -> Void
    ) {
        withCompletion({ try await self.theme(accountId: accountId) }, completion: completion)
    }

    /// Fetches account KPIs and delivers the result on the **main queue**.
    @objc(statsWithParams:accountId:completion:)
    public func stats(
        params: AccountStatsParams,
        accountId: String?,
        completion: @escaping ([DocumentStatsRow]?, Error?) -> Void
    ) {
        withCompletion({ try await self.stats(params: params, accountId: accountId) }, completion: completion)
    }

    /// Downloads the account logo and delivers the bytes on the **main queue**.
    @objc(downloadLogoWithAccountId:completion:)
    public func downloadLogo(
        accountId: String?,
        completion: @escaping (Data?, Error?) -> Void
    ) {
        withCompletion({ try await self.downloadLogo(accountId: accountId) }, completion: completion)
    }

    /// Uploads the account logo and notifies the **main queue** upon completion.
    @objc(uploadLogo:filename:contentType:accountId:completion:)
    public func uploadLogo(
        _ imageData: Data,
        filename: String,
        contentType: String,
        accountId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({
            try await self.uploadLogo(imageData, filename: filename, contentType: contentType, accountId: accountId)
        }, completion: completion)
    }

    /// Deletes the account logo and notifies the **main queue** upon completion.
    @objc(deleteLogoWithAccountId:completion:)
    public func deleteLogo(
        accountId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.deleteLogo(accountId: accountId) }, completion: completion)
    }
}
