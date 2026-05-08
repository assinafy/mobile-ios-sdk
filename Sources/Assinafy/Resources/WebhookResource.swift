import Foundation

/// Manages webhook subscriptions and delivery history.
///
/// Access this resource through ``AssinafyClient/webhooks``.
///
/// ## Example
/// ```swift
/// let sub = try await client.webhooks.register(
///     WebhookRegisterPayload(url: "https://example.com/hook", email: "ops@example.com"),
///     accountId: "acc_id"
/// )
/// ```
@objcMembers
public final class WebhookResource: BaseResource {

    // MARK: - Swift async API

    /// Registers or updates a webhook subscription for a workspace.
    ///
    /// - Parameters:
    ///   - payload: The webhook URL, notification email, and event types to subscribe to.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: The created or updated ``WebhookSubscription``.
    public func register(
        _ payload: WebhookRegisterPayload,
        accountId: String? = nil
    ) async throws -> WebhookSubscription {
        let id = try self.accountId(accountId)
        let request = try APIRequest.put("/accounts/\(id)/webhooks/subscriptions", body: payload)
        return try await call("Failed to register webhook", request: request)
    }

    /// Fetches the active webhook subscription for a workspace.
    ///
    /// - Parameter accountId: Override the client's default account ID.
    /// - Returns: The current ``WebhookSubscription``.
    public func get(accountId: String? = nil) async throws -> WebhookSubscription {
        let id = try self.accountId(accountId)
        return try await call("Failed to fetch webhook", request: .get("/accounts/\(id)/webhooks/subscriptions"))
    }

    /// Deletes the webhook subscription for a workspace.
    ///
    /// - Parameter accountId: Override the client's default account ID.
    public func delete(accountId: String? = nil) async throws {
        let id = try self.accountId(accountId)
        try await callVoid("Failed to delete webhook", request: .delete("/accounts/\(id)/webhooks/subscriptions"))
    }

    /// Deactivates the webhook subscription without deleting it.
    ///
    /// - Parameter accountId: Override the client's default account ID.
    public func inactivate(accountId: String? = nil) async throws {
        let id = try self.accountId(accountId)
        let request = APIRequest.put("/accounts/\(id)/webhooks/inactivate")
        try await callVoid("Failed to inactivate webhook", request: request)
    }

    /// Lists all available webhook event types on the platform.
    ///
    /// - Returns: An array of ``WebhookEventTypeInfo`` objects.
    public func listEventTypes() async throws -> [WebhookEventTypeInfo] {
        let result: PaginatedResult<WebhookEventTypeInfo> = try await callList(
            "Failed to list webhook event types",
            request: .get("/webhooks/event-types")
        )
        return result.data
    }

    /// Lists past webhook dispatch attempts for a workspace.
    ///
    /// - Parameters:
    ///   - params: Filter and pagination options.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: A ``PaginatedResult`` of ``WebhookDispatch`` objects.
    public func listDispatches(
        params: WebhookDispatchListParams = WebhookDispatchListParams(),
        accountId: String? = nil
    ) async throws -> PaginatedResult<WebhookDispatch> {
        let id = try self.accountId(accountId)
        let items = params.toQueryItems()
        return try await callList("Failed to list webhook dispatches",
                                  request: .get("/accounts/\(id)/webhooks",
                                                queryItems: items.isEmpty ? nil : items))
    }

    /// Retries a failed webhook delivery.
    ///
    /// - Parameters:
    ///   - dispatchId: The unique identifier of the failed delivery.
    ///   - accountId: Override the client's default account ID.
    public func retryDispatch(dispatchId: String, accountId: String? = nil) async throws -> WebhookDispatch {
        let id = try self.accountId(accountId)
        let did = try requireId(dispatchId, name: "Dispatch ID")
        let request = APIRequest.post("/accounts/\(id)/webhooks/\(did)/retry")
        return try await call("Failed to retry webhook dispatch", request: request)
    }

    // MARK: - Objective-C / completion-handler API

    /// Registers a webhook and delivers the result on the **main queue**.
    @objc(registerWebhook:accountId:completion:)
    public func register(
        _ payload: WebhookRegisterPayload,
        accountId: String?,
        completion: @escaping (WebhookSubscription?, Error?) -> Void
    ) {
        withCompletion({ try await self.register(payload, accountId: accountId) }, completion: completion)
    }

    /// Fetches the active subscription and delivers the result on the **main queue**.
    @objc(getWebhookWithAccountId:completion:)
    public func get(
        accountId: String?,
        completion: @escaping (WebhookSubscription?, Error?) -> Void
    ) {
        withCompletion({ try await self.get(accountId: accountId) }, completion: completion)
    }

    /// Deletes the webhook subscription and notifies the **main queue** upon completion.
    @objc(deleteWebhookWithAccountId:completion:)
    public func delete(
        accountId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.delete(accountId: accountId) }, completion: completion)
    }

    /// Lists dispatch records and delivers them on the **main queue**.
    @objc(listDispatchesWithAccountId:completion:)
    public func listDispatches(
        accountId: String?,
        completion: @escaping ([WebhookDispatch]?, Error?) -> Void
    ) {
        withListCompletion({ try await self.listDispatches(accountId: accountId) }, completion: completion)
    }
}
