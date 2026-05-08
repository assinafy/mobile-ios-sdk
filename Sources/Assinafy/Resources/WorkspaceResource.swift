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
    /// - Parameter params: Pagination and search parameters.
    /// - Returns: A ``PaginatedResult`` of ``WorkspaceListItem`` objects.
    public func list(params: ListParams = ListParams()) async throws -> PaginatedResult<WorkspaceListItem> {
        let items = params.toQueryItems()
        return try await callList("Failed to list workspaces",
                                  request: .get("/accounts",
                                                queryItems: items.isEmpty ? nil : items))
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
    /// - Parameter workspaceId: The workspace identifier.
    public func delete(workspaceId: String) async throws {
        let wid = try requireId(workspaceId, name: "Workspace ID")
        try await callVoid("Failed to delete workspace", request: .delete("/accounts/\(wid)"))
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
    @objc(deleteWorkspaceWithId:completion:)
    public func delete(
        workspaceId: String,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.delete(workspaceId: workspaceId) }, completion: completion)
    }
}
