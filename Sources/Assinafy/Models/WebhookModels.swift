import Foundation

// MARK: - WebhookEventType

/// Known webhook event type strings emitted by the Assinafy platform.
@objcMembers
public final class WebhookEventType: NSObject {
    @objc public static let documentUploaded        = "document_uploaded"
    @objc public static let documentMetadataReady   = "document_metadata_ready"
    @objc public static let documentPrepared        = "document_prepared"
    @objc public static let assignmentCreated       = "assignment_created"
    @objc public static let documentReady           = "document_ready"
    @objc public static let signatureRequested      = "signature_requested"
    @objc public static let signerCreated           = "signer_created"
    @objc public static let signerEmailVerified     = "signer_email_verified"
    @objc public static let signerWhatsappVerified  = "signer_whatsapp_verified"
    @objc public static let signerDataConfirmed     = "signer_data_confirmed"
    @objc public static let signerViewedDocument    = "signer_viewed_document"
    @objc public static let signerSignedDocument    = "signer_signed_document"
    @objc public static let signerRejectedDocument  = "signer_rejected_document"
    @objc public static let userRejectedDocument    = "user_rejected_document"
    @objc public static let documentProcessingFailed = "document_processing_failed"
    @objc public static let templateCreated         = "template_created"
    @objc public static let templateProcessed       = "template_processed"
    @objc public static let templateProcessingFailed = "template_processing_failed"

    /// The default set of events registered when none are specified.
    @objc public static let defaultEvents: [String] = [
        documentReady,
        documentPrepared,
        signerSignedDocument,
        signerRejectedDocument,
        documentProcessingFailed,
    ]
}

extension WebhookEventType: @unchecked Sendable {}

// MARK: - WebhookRegisterPayload

/// Payload for registering or updating a webhook subscription.
@objcMembers
public final class WebhookRegisterPayload: NSObject, Encodable {
    public let url: String
    public let email: String
    public let events: [String]
    public let isActive: Bool

    /// Creates a webhook registration payload.
    ///
    /// - Parameters:
    ///   - url: The HTTPS endpoint that will receive delivery POST requests.
    ///   - email: Contact email for delivery failure notifications.
    ///   - events: Specific event types to subscribe to. Defaults to ``WebhookEventType/defaultEvents``.
    ///   - isActive: Whether the subscription is active. Defaults to `true`.
    @objc public init(url: String, email: String, events: [String]? = nil, isActive: Bool = true) {
        self.url = url; self.email = email
        self.events = events ?? WebhookEventType.defaultEvents
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case url, email, events
        case isActive = "is_active"
    }
}

extension WebhookRegisterPayload: @unchecked Sendable {}

// MARK: - WebhookSubscription

/// The current webhook subscription configuration for a workspace.
@objcMembers
public final class WebhookSubscription: NSObject {
    public let id: String?
    public let url: String?
    public let email: String?
    public let events: [String]
    public let isActive: Bool
    public let createdAt: String?
    public let updatedAt: String?

    init(id: String? = nil, url: String?, email: String?, events: [String],
         isActive: Bool, createdAt: String? = nil, updatedAt: String? = nil) {
        self.id = id; self.url = url; self.email = email
        self.events = events; self.isActive = isActive
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

extension WebhookSubscription: @unchecked Sendable {}

extension WebhookSubscription: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, url, email, events
        case isActive  = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:        try c.decodeIfPresent(String.self,   forKey: .id),
            url:       try c.decodeIfPresent(String.self,   forKey: .url),
            email:     try c.decodeIfPresent(String.self,   forKey: .email),
            events:    (try? c.decode([String].self, forKey: .events)) ?? [],
            isActive:  try c.decodeIfPresent(Bool.self,     forKey: .isActive) ?? false,
            createdAt: try c.decodeIfPresent(String.self,   forKey: .createdAt),
            updatedAt: try c.decodeIfPresent(String.self,   forKey: .updatedAt)
        )
    }
}

// MARK: - WebhookEventTypeInfo

/// Metadata for a single webhook event type returned by the platform.
@objcMembers
public final class WebhookEventTypeInfo: NSObject {
    public let id: String
    public let eventDescription: String

    init(id: String, eventDescription: String) {
        self.id = id; self.eventDescription = eventDescription
    }
}

extension WebhookEventTypeInfo: @unchecked Sendable {}

extension WebhookEventTypeInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case eventDescription = "description"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:               try c.decode(String.self, forKey: .id),
            eventDescription: try c.decode(String.self, forKey: .eventDescription)
        )
    }
}

// MARK: - WebhookDispatch

/// A single webhook delivery attempt record.
@objcMembers
public final class WebhookDispatch: NSObject {
    /// Resource discriminator returned for a single dispatch history entry.
    public let resource: String?
    public let id: String
    public let event: String
    public let activityId: Int
    public let endpoint: String?
    /// JSON object delivered to the webhook endpoint, or `nil` when unavailable.
    public let payload: [String: Any]?
    public let delivered: Bool
    /// HTTP status returned by the endpoint, or `nil` when the connection failed.
    public let httpStatusCode: NSNumber?
    /// Compatibility view of ``httpStatusCode``; connection failures map to `0`.
    @available(*, deprecated, message: "Use httpStatusCode to distinguish a missing status from HTTP 0.")
    public var httpStatus: Int { httpStatusCode?.intValue ?? 0 }
    public let responseBody: String?
    public let deliveryError: String?
    /// ISO-8601 timestamp of the first delivery attempt (e.g. `2026-07-20T19:03:13Z`).
    public let createdAt: String?
    /// ISO-8601 timestamp of the most recent delivery attempt.
    public let updatedAt: String?

    init(resource: String? = nil, id: String, event: String, activityId: Int,
         endpoint: String? = nil, payload: [String: Any]? = nil,
         delivered: Bool, httpStatusCode: NSNumber? = nil, responseBody: String? = nil,
         deliveryError: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.resource = resource
        self.id = id; self.event = event; self.activityId = activityId
        self.endpoint = endpoint; self.payload = payload; self.delivered = delivered
        self.httpStatusCode = httpStatusCode
        self.responseBody = responseBody; self.deliveryError = deliveryError
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

extension WebhookDispatch: @unchecked Sendable {}

extension WebhookDispatch: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, event, endpoint, payload, delivered
        case activityId  = "activity_id"
        case httpStatus  = "http_status"
        case responseBody = "response_body"
        case deliveryError = "error"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            resource:     try c.decodeIfPresent(String.self,   forKey: .resource),
            id:           try c.decode(String.self,           forKey: .id),
            event:        try c.decode(String.self,           forKey: .event),
            activityId:   try c.decode(Int.self,              forKey: .activityId),
            endpoint:     try c.decodeIfPresent(String.self,  forKey: .endpoint),
            payload:      try Self.decodePayload(from: c),
            delivered:    try c.decode(Bool.self,             forKey: .delivered),
            httpStatusCode: try c.decodeIfPresent(Int.self, forKey: .httpStatus).map {
                NSNumber(value: $0)
            },
            responseBody: try c.decodeIfPresent(String.self,  forKey: .responseBody),
            deliveryError:try c.decodeIfPresent(String.self,  forKey: .deliveryError),
            createdAt:    try decodeFlexibleOptionalString(from: c, forKey: .createdAt),
            updatedAt:    try decodeFlexibleOptionalString(from: c, forKey: .updatedAt)
        )
    }

    private static func decodePayload(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [String: Any]? {
        guard let fragment = try container.decodeIfPresent(JSONFragment.self, forKey: .payload),
              case .object = fragment.storage else {
            return nil
        }
        let data = try JSONEncoder.assinafy.encode(fragment)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

// MARK: - WebhookDispatchListParams

/// Filter and pagination parameters for ``WebhookResource/listDispatches(params:accountId:)``.
@objcMembers
public final class WebhookDispatchListParams: NSObject {
    public var page: Int
    public var perPage: Int
    public var event: String?
    public var delivered: Bool
    public var hasDeliveredFilter: Bool
    public var from: Int
    public var to: Int
    public var hasTimeFilter: Bool

    /// Creates webhook-dispatch pagination and optional filters.
    /// - Parameters:
    ///   - page: One-based page number.
    ///   - perPage: Maximum dispatches per page.
    ///   - event: Optional webhook event name.
    ///   - delivered: Delivery state used when `hasDeliveredFilter` is `true`.
    ///   - hasDeliveredFilter: Whether to include the delivery-state filter.
    ///   - from: Inclusive Unix-time lower bound.
    ///   - to: Inclusive Unix-time upper bound.
    ///   - hasTimeFilter: Whether to include supplied time bounds.
    @objc public init(
        page: Int = 0,
        perPage: Int = 0,
        event: String? = nil,
        delivered: Bool = false,
        hasDeliveredFilter: Bool = false,
        from: Int = 0,
        to: Int = 0,
        hasTimeFilter: Bool = false
    ) {
        self.page = page; self.perPage = perPage; self.event = event
        self.delivered = delivered; self.hasDeliveredFilter = hasDeliveredFilter
        self.from = from; self.to = to; self.hasTimeFilter = hasTimeFilter
    }

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if page > 0     { items.append(.init(name: "page",     value: "\(page)")) }
        if perPage > 0  { items.append(.init(name: "per-page", value: "\(perPage)")) }
        if let e = event { items.append(.init(name: "event",   value: e)) }
        if hasDeliveredFilter {
            items.append(.init(name: "delivered", value: delivered ? "true" : "false"))
        }
        if hasTimeFilter {
            if from > 0 { items.append(.init(name: "from", value: "\(from)")) }
            if to   > 0 { items.append(.init(name: "to",   value: "\(to)")) }
        }
        return items
    }
}

extension WebhookDispatchListParams: @unchecked Sendable {}
