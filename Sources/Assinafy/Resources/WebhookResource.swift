import Foundation

/// Manages webhook endpoints, signing secrets, subscriptions and delivery history.
///
/// A workspace has one webhook endpoint, or up to three on paid plans. The
/// `subscriptions` routes (``register(_:accountId:)``, ``get(accountId:)``,
/// ``inactivate(accountId:)``) act on the oldest endpoint; use the `endpoints`
/// methods to manage several.
///
/// Access this resource through ``AssinafyClient/webhooks``.
///
/// ## Example
/// ```swift
/// let sub = try await client.webhooks.register(
///     WebhookRegisterPayload(url: "https://example.invalid/hook", email: "ops@example.invalid"),
///     accountId: "acc_id"
/// )
/// ```
@objcMembers
public final class WebhookResource: BaseResource, @unchecked Sendable {

    // MARK: - Swift async API

    /// Registers or updates the workspace's oldest webhook endpoint.
    ///
    /// Mirrors `PUT /accounts/{accountId}/webhooks/subscriptions`.
    ///
    /// - Parameters:
    ///   - payload: The webhook URL, notification email, and event types to subscribe to.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: The created or updated ``WebhookSubscription``.
    public func register(
        _ payload: WebhookRegisterPayload,
        accountId: String? = nil
    ) async throws -> WebhookSubscription {
        try validateTarget(url: payload.url, email: payload.email, events: payload.events)
        let id = try self.accountId(accountId)
        let request = try APIRequest.put("/accounts/\(id)/webhooks/subscriptions", body: payload)
        return try await call("Failed to register webhook", request: request)
    }

    /// Fetches the workspace's oldest webhook endpoint.
    ///
    /// Mirrors `GET /accounts/{accountId}/webhooks/subscriptions`.
    ///
    /// - Parameter accountId: Override the client's default account ID.
    /// - Returns: The current ``WebhookSubscription``.
    public func get(accountId: String? = nil) async throws -> WebhookSubscription {
        let id = try self.accountId(accountId)
        return try await call("Failed to fetch webhook", request: .get("/accounts/\(id)/webhooks/subscriptions"))
    }

    /// Stops webhook delivery for a workspace.
    ///
    /// - Important: The Assinafy API has no destructive delete for subscriptions;
    ///   the supported operation is deactivation. This method forwards to
    ///   ``inactivate(accountId:)`` and is retained only for source compatibility.
    ///
    /// - Parameter accountId: Override the client's default account ID.
    @available(*, deprecated, renamed: "inactivate(accountId:)",
               message: "The API has no DELETE for webhook subscriptions; use inactivate(accountId:).")
    public func delete(accountId: String? = nil) async throws {
        try await inactivate(accountId: accountId)
    }

    /// Deactivates the webhook subscription without deleting it.
    ///
    /// - Parameter accountId: Override the client's default account ID.
    public func inactivate(accountId: String? = nil) async throws {
        let id = try self.accountId(accountId)
        let request = APIRequest.put("/accounts/\(id)/webhooks/inactivate")
        try await callVoid("Failed to inactivate webhook", request: request)
    }

    /// Deactivates the webhook subscription and returns its updated configuration.
    ///
    /// This additive variant exposes the documented response body while
    /// ``inactivate(accountId:)`` retains its original `Void` return type for
    /// source compatibility.
    ///
    /// - Parameter accountId: Override the client's default account ID.
    /// - Returns: The inactivated ``WebhookSubscription``.
    public func inactivateAndReturn(accountId: String? = nil) async throws -> WebhookSubscription {
        let id = try self.accountId(accountId)
        let request = APIRequest.put("/accounts/\(id)/webhooks/inactivate")
        return try await call("Failed to inactivate webhook", request: request)
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

    // MARK: Endpoints

    /// Lists the workspace's webhook endpoints, oldest first.
    ///
    /// Mirrors `GET /accounts/{accountId}/webhooks/endpoints`. OAuth scope: `account:read`.
    public func listEndpoints(accountId: String? = nil) async throws -> [WebhookEndpoint] {
        let id = try self.accountId(accountId)
        let result: PaginatedResult<WebhookEndpoint> = try await callList(
            "Failed to list webhook endpoints", request: .get("/accounts/\(id)/webhooks/endpoints"))
        return result.data
    }

    /// Creates a webhook endpoint.
    ///
    /// Mirrors `POST /accounts/{accountId}/webhooks/endpoints`. OAuth scope: `webhooks:write`.
    /// The API answers `403` past the plan's endpoint limit and `400` when another
    /// endpoint already uses the URL. With `signingEnabled`, read the generated
    /// secret with ``signingSecret(endpointId:accountId:)``.
    public func createEndpoint(
        _ payload: CreateWebhookEndpointPayload,
        accountId: String? = nil
    ) async throws -> WebhookEndpoint {
        try validateTarget(url: payload.url, email: payload.email, events: payload.events)
        let id = try self.accountId(accountId)
        let request = try APIRequest.post("/accounts/\(id)/webhooks/endpoints", body: payload)
        return try await call("Failed to create webhook endpoint", request: request)
    }

    /// Fetches one webhook endpoint.
    ///
    /// Mirrors `GET /accounts/{accountId}/webhooks/endpoints/{endpointId}`. OAuth scope: `account:read`.
    public func getEndpoint(id endpointId: String, accountId: String? = nil) async throws -> WebhookEndpoint {
        let path = try endpointPath(endpointId, accountId: accountId)
        return try await call("Failed to fetch webhook endpoint", request: .get(path))
    }

    /// Updates the fields set on `payload`.
    ///
    /// Mirrors `PUT /accounts/{accountId}/webhooks/endpoints/{endpointId}`. OAuth scope: `webhooks:write`.
    public func updateEndpoint(
        id endpointId: String,
        _ payload: UpdateWebhookEndpointPayload,
        accountId: String? = nil
    ) async throws -> WebhookEndpoint {
        guard !payload.isEmpty else {
            throw ValidationError("Webhook endpoint update must change at least one field")
        }
        if let url = payload.url { try validateURL(url) }
        if let email = payload.email { try validateEmail(email) }
        if let events = payload.events { try validateEvents(events) }
        let path = try endpointPath(endpointId, accountId: accountId)
        return try await call("Failed to update webhook endpoint", request: try .put(path, body: payload))
    }

    /// Deletes a webhook endpoint and frees its slot.
    ///
    /// Mirrors `DELETE /accounts/{accountId}/webhooks/endpoints/{endpointId}`. OAuth scope: `webhooks:write`.
    public func deleteEndpoint(id endpointId: String, accountId: String? = nil) async throws {
        let path = try endpointPath(endpointId, accountId: accountId)
        try await callVoid("Failed to delete webhook endpoint", request: .delete(path))
    }

    /// Returns the endpoint's `whsec_` signing secret for ``WebhookSignature``.
    ///
    /// Mirrors `GET /accounts/{accountId}/webhooks/endpoints/{endpointId}/secret`.
    /// The API answers `400` when signing is disabled. Not available to OAuth applications.
    public func signingSecret(endpointId: String, accountId: String? = nil) async throws -> String {
        let path = try endpointPath(endpointId, accountId: accountId) + "/secret"
        let result: WebhookSigningSecret = try await call("Failed to fetch webhook signing secret",
                                                          request: .get(path))
        return result.secret
    }

    /// Replaces the endpoint's signing secret and returns the new one.
    ///
    /// Mirrors `POST /accounts/{accountId}/webhooks/endpoints/{endpointId}/secret/rotate`.
    /// The old secret stops working immediately. The API answers `400` when signing
    /// is disabled. Not available to OAuth applications.
    public func rotateSigningSecret(endpointId: String, accountId: String? = nil) async throws -> String {
        let path = try endpointPath(endpointId, accountId: accountId) + "/secret/rotate"
        let result: WebhookSigningSecret = try await call("Failed to rotate webhook signing secret",
                                                          request: .post(path))
        return result.secret
    }

    // MARK: Validation

    private func endpointPath(_ endpointId: String, accountId: String?) throws -> String {
        let id = try self.accountId(accountId)
        let eid = try requireId(endpointId, name: "Endpoint ID")
        return "/accounts/\(id)/webhooks/endpoints/\(eid)"
    }

    private func validateTarget(url: String, email: String, events: [String]) throws {
        try validateURL(url)
        try validateEmail(email)
        try validateEvents(events)
    }

    private func validateURL(_ url: String) throws {
        guard let components = URLComponents(string: url),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil else {
            throw ValidationError("Webhook URL must be an absolute HTTP or HTTPS URL")
        }
    }

    private func validateEvents(_ events: [String]) throws {
        guard events.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ValidationError("Webhook event names must not be blank")
        }
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

    /// Stops webhook delivery and notifies the **main queue** upon completion.
    ///
    /// - Note: Forwards to ``inactivate(accountId:)`` — the API has no destructive
    ///   delete for subscriptions.
    @objc(deleteWebhookWithAccountId:completion:)
    public func delete(
        accountId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.inactivate(accountId: accountId) }, completion: completion)
    }

    /// Deactivates the webhook subscription and notifies the **main queue** upon completion.
    @objc(inactivateWebhookWithAccountId:completion:)
    public func inactivate(
        accountId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.inactivate(accountId: accountId) }, completion: completion)
    }

    /// Deactivates the subscription and delivers its updated configuration on the **main queue**.
    @objc(inactivateWebhookAndReturnWithAccountId:completion:)
    public func inactivateAndReturn(
        accountId: String?,
        completion: @escaping (WebhookSubscription?, Error?) -> Void
    ) {
        withCompletion({ try await self.inactivateAndReturn(accountId: accountId) }, completion: completion)
    }

    /// Lists dispatch records and delivers them on the **main queue**.
    @objc(listDispatchesWithAccountId:completion:)
    public func listDispatches(
        accountId: String?,
        completion: @escaping ([WebhookDispatch]?, Error?) -> Void
    ) {
        withListCompletion({ try await self.listDispatches(accountId: accountId) }, completion: completion)
    }

    /// Completion form of `listEventTypes`; delivers the result on the main queue.
    @objc(listEventTypesWithCompletion:)
    public func listEventTypes(
        completion: @escaping ([WebhookEventTypeInfo]?, Error?) -> Void
    ) {
        withCompletion({ try await self.listEventTypes() }, completion: completion)
    }

    /// Completion form of `listDispatches`; delivers the result on the main queue.
    @objc(listDispatchesWithWebhookDispatchListParams:accountId:completion:)
    public func listDispatches(
        params: WebhookDispatchListParams,
        accountId: String?,
        completion: @escaping ([WebhookDispatch]?, Error?) -> Void
    ) {
        withListCompletion({ try await self.listDispatches(params: params, accountId: accountId) }, completion: completion)
    }

    /// Completion form of `retryDispatch`; delivers the result on the main queue.
    @objc(retryDispatchWithDispatchId:accountId:completion:)
    public func retryDispatch(
        dispatchId: String,
        accountId: String?,
        completion: @escaping (WebhookDispatch?, Error?) -> Void
    ) {
        withCompletion({ try await self.retryDispatch(dispatchId: dispatchId, accountId: accountId) }, completion: completion)
    }

    /// Completion form of `listEndpoints`; delivers the result on the main queue.
    @objc(listWebhookEndpointsWithAccountId:completion:)
    public func listEndpoints(
        accountId: String?,
        completion: @escaping ([WebhookEndpoint]?, Error?) -> Void
    ) {
        withCompletion({ try await self.listEndpoints(accountId: accountId) }, completion: completion)
    }

    /// Completion form of `createEndpoint`; delivers the result on the main queue.
    @objc(createWebhookEndpoint:accountId:completion:)
    public func createEndpoint(
        _ payload: CreateWebhookEndpointPayload,
        accountId: String?,
        completion: @escaping (WebhookEndpoint?, Error?) -> Void
    ) {
        withCompletion({ try await self.createEndpoint(payload, accountId: accountId) }, completion: completion)
    }

    /// Completion form of `getEndpoint`; delivers the result on the main queue.
    @objc(getWebhookEndpointWithId:accountId:completion:)
    public func getEndpoint(
        id endpointId: String,
        accountId: String?,
        completion: @escaping (WebhookEndpoint?, Error?) -> Void
    ) {
        withCompletion({ try await self.getEndpoint(id: endpointId, accountId: accountId) }, completion: completion)
    }

    /// Completion form of `updateEndpoint`; delivers the result on the main queue.
    @objc(updateWebhookEndpointWithId:payload:accountId:completion:)
    public func updateEndpoint(
        id endpointId: String,
        _ payload: UpdateWebhookEndpointPayload,
        accountId: String?,
        completion: @escaping (WebhookEndpoint?, Error?) -> Void
    ) {
        withCompletion({ try await self.updateEndpoint(id: endpointId, payload, accountId: accountId) },
                       completion: completion)
    }

    /// Completion form of `deleteEndpoint`; notifies the main queue.
    @objc(deleteWebhookEndpointWithId:accountId:completion:)
    public func deleteEndpoint(
        id endpointId: String,
        accountId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.deleteEndpoint(id: endpointId, accountId: accountId) },
                           completion: completion)
    }

    /// Completion form of `signingSecret`; delivers the result on the main queue.
    @objc(webhookSigningSecretWithEndpointId:accountId:completion:)
    public func signingSecret(
        endpointId: String,
        accountId: String?,
        completion: @escaping (NSString?, Error?) -> Void
    ) {
        withCompletion({ try await self.signingSecret(endpointId: endpointId, accountId: accountId) as NSString },
                       completion: completion)
    }

    /// Completion form of `rotateSigningSecret`; delivers the result on the main queue.
    @objc(rotateWebhookSigningSecretWithEndpointId:accountId:completion:)
    public func rotateSigningSecret(
        endpointId: String,
        accountId: String?,
        completion: @escaping (NSString?, Error?) -> Void
    ) {
        withCompletion({ try await self.rotateSigningSecret(endpointId: endpointId, accountId: accountId) as NSString },
                       completion: completion)
    }

}
