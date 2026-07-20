import Foundation

// MARK: - NotificationSenderType

/// Who signer notification emails/messages appear to come from.
///
/// Maps to the account `notification_sender_type` field. Branding colours are
/// **not** part of the account create/update body — read them from
/// ``AccountTheme`` via ``WorkspaceResource/theme(accountId:)``.
@objcMembers
public final class NotificationSenderType: NSObject {
    /// Notifications are sent on behalf of the individual user.
    @objc public static let user    = "User"
    /// Notifications are sent on behalf of the account (workspace).
    @objc public static let account = "Account"
}

extension NotificationSenderType: @unchecked Sendable {}

// MARK: - CreateWorkspacePayload

/// Payload for creating a new workspace (account).
///
/// Mirrors `POST /accounts` — body `{ name, notification_sender_type }`.
@objcMembers
public final class CreateWorkspacePayload: NSObject, Encodable {
    public let name: String
    /// `"User"` or `"Account"` (see ``NotificationSenderType``). Optional.
    public let notificationSenderType: String?

    @objc public init(name: String, notificationSenderType: String? = nil) {
        self.name = name
        self.notificationSenderType = notificationSenderType
    }

    enum CodingKeys: String, CodingKey {
        case name
        case notificationSenderType = "notification_sender_type"
    }
}

extension CreateWorkspacePayload: @unchecked Sendable {}

// MARK: - UpdateWorkspacePayload

/// Payload for updating an existing workspace. Only supply the fields to change.
///
/// Mirrors `PUT /accounts/{id}` — body `{ name, notification_sender_type }`.
@objcMembers
public final class UpdateWorkspacePayload: NSObject, Encodable {
    public let name: String?
    /// `"User"` or `"Account"` (see ``NotificationSenderType``). Optional.
    public let notificationSenderType: String?

    @objc public init(name: String? = nil, notificationSenderType: String? = nil) {
        self.name = name
        self.notificationSenderType = notificationSenderType
    }

    enum CodingKeys: String, CodingKey {
        case name
        case notificationSenderType = "notification_sender_type"
    }
}

extension UpdateWorkspacePayload: @unchecked Sendable {}

// MARK: - WorkspaceResponse

/// A workspace (account) returned by the API.
@objcMembers
public final class WorkspaceResponse: NSObject {
    public let id: String
    public let name: String
    public let primaryColor: String?
    public let secondaryColor: String?
    public let createdAt: String

    init(id: String, name: String, primaryColor: String? = nil,
         secondaryColor: String? = nil, createdAt: String) {
        self.id = id; self.name = name
        self.primaryColor = primaryColor; self.secondaryColor = secondaryColor
        self.createdAt = createdAt
    }
}

extension WorkspaceResponse: @unchecked Sendable {}

extension WorkspaceResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name
        case primaryColor   = "primary_color"
        case secondaryColor = "secondary_color"
        case createdAt      = "created_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:             try c.decode(String.self,          forKey: .id),
            name:           try c.decode(String.self,          forKey: .name),
            primaryColor:   try c.decodeIfPresent(String.self, forKey: .primaryColor),
            secondaryColor: try c.decodeIfPresent(String.self, forKey: .secondaryColor),
            createdAt:      try c.decode(String.self,          forKey: .createdAt)
        )
    }
}

// MARK: - WorkspaceListItem

/// A workspace summary item in a paginated list response.
@objcMembers
public final class WorkspaceListItem: NSObject {
    public let id: String
    public let name: String
    public let isDeleteAllowed: Bool
    public let roles: [String]
    public let createdAt: String

    init(id: String, name: String, isDeleteAllowed: Bool, roles: [String], createdAt: String) {
        self.id = id; self.name = name
        self.isDeleteAllowed = isDeleteAllowed; self.roles = roles
        self.createdAt = createdAt
    }
}

extension WorkspaceListItem: @unchecked Sendable {}

extension WorkspaceListItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, roles
        case isDeleteAllowed = "is_delete_allowed"
        case createdAt       = "created_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:              try c.decode(String.self,   forKey: .id),
            name:            try c.decode(String.self,   forKey: .name),
            isDeleteAllowed: try c.decodeIfPresent(Bool.self, forKey: .isDeleteAllowed) ?? false,
            roles:           (try? c.decode([String].self, forKey: .roles)) ?? [],
            createdAt:       try c.decode(String.self,   forKey: .createdAt)
        )
    }
}

// MARK: - AccountTheme

/// An account's branding theme, returned by `GET /accounts/{id}/theme`.
///
/// This is the canonical source of an account's branding colours — the account
/// create/update body does not carry colours.
@objcMembers
public final class AccountTheme: NSObject {
    public let accountName: String?
    /// Primary colour as a hex string without a leading `#` (e.g. `2072b9`).
    public let primaryColor: String?
    /// Secondary colour as a hex string without a leading `#`.
    public let secondaryColor: String?
    /// URL of the account logo, or `nil` when none is set.
    public let logo: String?

    init(accountName: String?, primaryColor: String?, secondaryColor: String?, logo: String?) {
        self.accountName = accountName
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.logo = logo
    }
}

extension AccountTheme: @unchecked Sendable {}

extension AccountTheme: Decodable {
    enum CodingKeys: String, CodingKey {
        case accountName    = "account_name"
        case primaryColor   = "primary_color"
        case secondaryColor = "secondary_color"
        case logo
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            accountName:    try c.decodeIfPresent(String.self, forKey: .accountName),
            primaryColor:   try c.decodeIfPresent(String.self, forKey: .primaryColor),
            secondaryColor: try c.decodeIfPresent(String.self, forKey: .secondaryColor),
            logo:           try c.decodeIfPresent(String.self, forKey: .logo)
        )
    }
}

// MARK: - DocumentStatsRow

/// One period of the document-funnel KPI series returned by the account and
/// user statistics endpoints (`GET /accounts/{id}/stats`, `GET /users/self/stats`).
///
/// Series are zero-filled with no gaps. ``period`` is `YYYY-MM` for monthly
/// granularity or `YYYY-MM-DD` for daily.
@objcMembers
public final class DocumentStatsRow: NSObject {
    public let period: String
    public let documentsUploaded: Int
    public let documentsSent: Int
    public let signatureRequests: Int
    public let signatureRequestsEmail: Int
    public let signatureRequestsWhatsapp: Int
    public let documentsOpened: Int
    public let documentsSigned: Int
    public let documentsCertified: Int

    init(period: String, documentsUploaded: Int, documentsSent: Int,
         signatureRequests: Int, signatureRequestsEmail: Int, signatureRequestsWhatsapp: Int,
         documentsOpened: Int, documentsSigned: Int, documentsCertified: Int) {
        self.period = period
        self.documentsUploaded = documentsUploaded
        self.documentsSent = documentsSent
        self.signatureRequests = signatureRequests
        self.signatureRequestsEmail = signatureRequestsEmail
        self.signatureRequestsWhatsapp = signatureRequestsWhatsapp
        self.documentsOpened = documentsOpened
        self.documentsSigned = documentsSigned
        self.documentsCertified = documentsCertified
    }
}

extension DocumentStatsRow: @unchecked Sendable {}

extension DocumentStatsRow: Decodable {
    enum CodingKeys: String, CodingKey {
        case period
        case documentsUploaded         = "documents_uploaded"
        case documentsSent             = "documents_sent"
        case signatureRequests         = "signature_requests"
        case signatureRequestsEmail    = "signature_requests_email"
        case signatureRequestsWhatsapp = "signature_requests_whatsapp"
        case documentsOpened           = "documents_opened"
        case documentsSigned           = "documents_signed"
        case documentsCertified        = "documents_certified"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func int(_ k: CodingKeys) -> Int { (try? c.decodeIfPresent(Int.self, forKey: k)) ?? 0 }
        self.init(
            period:                    (try? c.decodeIfPresent(String.self, forKey: .period)) ?? "",
            documentsUploaded:         int(.documentsUploaded),
            documentsSent:             int(.documentsSent),
            signatureRequests:         int(.signatureRequests),
            signatureRequestsEmail:    int(.signatureRequestsEmail),
            signatureRequestsWhatsapp: int(.signatureRequestsWhatsapp),
            documentsOpened:           int(.documentsOpened),
            documentsSigned:           int(.documentsSigned),
            documentsCertified:        int(.documentsCertified)
        )
    }
}

// MARK: - AccountStatsParams

/// Query parameters for the document-funnel statistics endpoints.
@objcMembers
public final class AccountStatsParams: NSObject {
    /// `"monthly"` (default, last 12 months) or `"daily"`.
    public var granularity: String?
    /// `YYYY-MM` — required when ``granularity`` is `"daily"`.
    public var month: String?

    @objc public init(granularity: String? = nil, month: String? = nil) {
        self.granularity = granularity
        self.month = month
    }

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let g = granularity { items.append(.init(name: "granularity", value: g)) }
        if let m = month       { items.append(.init(name: "month", value: m)) }
        return items
    }
}

extension AccountStatsParams: @unchecked Sendable {}
