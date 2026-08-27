import Foundation

// MARK: - WorkspaceDeletionRestriction

/// A condition that prevents a workspace from being deleted without `force`.
@objcMembers
public final class WorkspaceDeletionRestriction: NSObject {
    /// Machine-readable code such as `ActivePaidSubscription` or `PendingDocuments`.
    public let code: String
    /// Human-readable explanation returned by the API.
    public let message: String
    /// Workspace IDs affected by this restriction.
    public let accountIds: [String]

    /// Creates a deletion restriction value.
    public init(code: String, message: String, accountIds: [String]) {
        self.code = code
        self.message = message
        self.accountIds = accountIds
    }
}

extension WorkspaceDeletionRestriction: @unchecked Sendable {}

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

    /// Creates a workspace request with an optional notification sender type.
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

    /// Creates a partial workspace update; omitted values remain unchanged.
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
    /// Resource discriminator returned by the API (normally `account`).
    public let resource: String?
    public let id: String
    public let name: String
    public let primaryColor: String?
    public let secondaryColor: String?
    /// `User` or `Account`.
    public let notificationSenderType: String?
    /// Roles held by the current user in this account.
    public let roles: [String]
    /// Whether the API currently permits deletion of this account.
    public let isDeleteAllowed: Bool
    public let createdAt: String

    init(resource: String? = nil, id: String, name: String, primaryColor: String? = nil,
         secondaryColor: String? = nil, notificationSenderType: String? = nil,
         roles: [String] = [], isDeleteAllowed: Bool = false, createdAt: String) {
        self.resource = resource
        self.id = id; self.name = name
        self.primaryColor = primaryColor; self.secondaryColor = secondaryColor
        self.notificationSenderType = notificationSenderType
        self.roles = roles
        self.isDeleteAllowed = isDeleteAllowed
        self.createdAt = createdAt
    }
}

extension WorkspaceResponse: @unchecked Sendable {}

extension WorkspaceResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, name, roles
        case primaryColor   = "primary_color"
        case secondaryColor = "secondary_color"
        case notificationSenderType = "notification_sender_type"
        case isDeleteAllowed = "is_delete_allowed"
        case createdAt      = "created_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            resource:        try c.decodeIfPresent(String.self, forKey: .resource),
            id:             try c.decode(String.self,          forKey: .id),
            name:           try c.decode(String.self,          forKey: .name),
            primaryColor:   try c.decodeIfPresent(String.self, forKey: .primaryColor),
            secondaryColor: try c.decodeIfPresent(String.self, forKey: .secondaryColor),
            notificationSenderType: try c.decodeIfPresent(String.self, forKey: .notificationSenderType),
            roles:           try c.decodeIfPresent([String].self, forKey: .roles) ?? [],
            isDeleteAllowed: try c.decodeIfPresent(Bool.self, forKey: .isDeleteAllowed) ?? false,
            createdAt:       try decodeFlexibleString(from: c, forKey: .createdAt)
        )
    }
}

// MARK: - WorkspaceListItem

/// A workspace summary item in a paginated list response.
@objcMembers
public final class WorkspaceListItem: NSObject {
    public let resource: String?
    public let id: String
    public let name: String
    public let primaryColor: String?
    public let secondaryColor: String?
    public let notificationSenderType: String?
    public let isDeleteAllowed: Bool
    public let roles: [String]
    public let createdAt: String

    init(resource: String? = nil, id: String, name: String,
         primaryColor: String? = nil, secondaryColor: String? = nil,
         notificationSenderType: String? = nil, isDeleteAllowed: Bool,
         roles: [String], createdAt: String) {
        self.resource = resource
        self.id = id; self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.notificationSenderType = notificationSenderType
        self.isDeleteAllowed = isDeleteAllowed; self.roles = roles
        self.createdAt = createdAt
    }
}

extension WorkspaceListItem: @unchecked Sendable {}

extension WorkspaceListItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, name, roles
        case primaryColor = "primary_color"
        case secondaryColor = "secondary_color"
        case notificationSenderType = "notification_sender_type"
        case isDeleteAllowed = "is_delete_allowed"
        case createdAt       = "created_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            resource:         try c.decodeIfPresent(String.self, forKey: .resource),
            id:              try c.decode(String.self,   forKey: .id),
            name:            try c.decode(String.self,   forKey: .name),
            primaryColor:    try c.decodeIfPresent(String.self, forKey: .primaryColor),
            secondaryColor:  try c.decodeIfPresent(String.self, forKey: .secondaryColor),
            notificationSenderType: try c.decodeIfPresent(String.self, forKey: .notificationSenderType),
            isDeleteAllowed: try c.decodeIfPresent(Bool.self, forKey: .isDeleteAllowed) ?? false,
            roles:           try c.decodeIfPresent([String].self, forKey: .roles) ?? [],
            createdAt:       try decodeFlexibleString(from: c, forKey: .createdAt)
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
    public let signatureRequestsNotificationBypass: Int
    public let signatureRequestsNotificationEmail: Int
    public let signatureRequestsNotificationWhatsapp: Int
    public let signatureRequestsVerificationBypass: Int
    public let signatureRequestsVerificationEmail: Int
    public let signatureRequestsVerificationWhatsapp: Int
    public let signatureRequestsVerificationDigitalCertificate: Int
    public let signatureRequestsViewed: Int
    public let signatureRequestsCompleted: Int
    public let documentsCertified: Int

    /// Compatibility alias for ``signatureRequestsNotificationEmail``.
    @available(*, deprecated, renamed: "signatureRequestsNotificationEmail")
    public var signatureRequestsEmail: Int { signatureRequestsNotificationEmail }
    /// Compatibility alias for ``signatureRequestsNotificationWhatsapp``.
    @available(*, deprecated, renamed: "signatureRequestsNotificationWhatsapp")
    public var signatureRequestsWhatsapp: Int { signatureRequestsNotificationWhatsapp }
    /// Compatibility alias for ``signatureRequestsViewed``.
    @available(*, deprecated, renamed: "signatureRequestsViewed")
    public var documentsOpened: Int { signatureRequestsViewed }
    /// Compatibility alias for ``signatureRequestsCompleted``.
    @available(*, deprecated, renamed: "signatureRequestsCompleted")
    public var documentsSigned: Int { signatureRequestsCompleted }

    init(period: String, documentsUploaded: Int, documentsSent: Int,
         signatureRequests: Int, signatureRequestsNotificationBypass: Int,
         signatureRequestsNotificationEmail: Int, signatureRequestsNotificationWhatsapp: Int,
         signatureRequestsVerificationBypass: Int, signatureRequestsVerificationEmail: Int,
         signatureRequestsVerificationWhatsapp: Int,
         signatureRequestsVerificationDigitalCertificate: Int,
         signatureRequestsViewed: Int, signatureRequestsCompleted: Int,
         documentsCertified: Int) {
        self.period = period
        self.documentsUploaded = documentsUploaded
        self.documentsSent = documentsSent
        self.signatureRequests = signatureRequests
        self.signatureRequestsNotificationBypass = signatureRequestsNotificationBypass
        self.signatureRequestsNotificationEmail = signatureRequestsNotificationEmail
        self.signatureRequestsNotificationWhatsapp = signatureRequestsNotificationWhatsapp
        self.signatureRequestsVerificationBypass = signatureRequestsVerificationBypass
        self.signatureRequestsVerificationEmail = signatureRequestsVerificationEmail
        self.signatureRequestsVerificationWhatsapp = signatureRequestsVerificationWhatsapp
        self.signatureRequestsVerificationDigitalCertificate = signatureRequestsVerificationDigitalCertificate
        self.signatureRequestsViewed = signatureRequestsViewed
        self.signatureRequestsCompleted = signatureRequestsCompleted
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
        case signatureRequestsNotificationBypass = "signature_requests_notification_bypass"
        case signatureRequestsNotificationEmail = "signature_requests_notification_email"
        case signatureRequestsNotificationWhatsapp = "signature_requests_notification_whatsapp"
        case signatureRequestsVerificationBypass = "signature_requests_verification_bypass"
        case signatureRequestsVerificationEmail = "signature_requests_verification_email"
        case signatureRequestsVerificationWhatsapp = "signature_requests_verification_whatsapp"
        case signatureRequestsVerificationDigitalCertificate = "signature_requests_verification_digital_certificate"
        case signatureRequestsViewed = "signature_requests_viewed"
        case signatureRequestsCompleted = "signature_requests_completed"
        case documentsCertified        = "documents_certified"
        case legacySignatureRequestsEmail = "signature_requests_email"
        case legacySignatureRequestsWhatsapp = "signature_requests_whatsapp"
        case legacyDocumentsOpened = "documents_opened"
        case legacyDocumentsSigned = "documents_signed"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func int(_ key: CodingKeys, legacyKey: CodingKeys? = nil) throws -> Int {
            if c.contains(key) { return try c.decodeIfPresent(Int.self, forKey: key) ?? 0 }
            if let legacyKey, c.contains(legacyKey) {
                return try c.decodeIfPresent(Int.self, forKey: legacyKey) ?? 0
            }
            return 0
        }
        self.init(
            period:                    try c.decodeIfPresent(String.self, forKey: .period) ?? "",
            documentsUploaded:         try int(.documentsUploaded),
            documentsSent:             try int(.documentsSent),
            signatureRequests:         try int(.signatureRequests),
            signatureRequestsNotificationBypass: try int(.signatureRequestsNotificationBypass),
            signatureRequestsNotificationEmail: try int(.signatureRequestsNotificationEmail,
                                                         legacyKey: .legacySignatureRequestsEmail),
            signatureRequestsNotificationWhatsapp: try int(.signatureRequestsNotificationWhatsapp,
                                                            legacyKey: .legacySignatureRequestsWhatsapp),
            signatureRequestsVerificationBypass: try int(.signatureRequestsVerificationBypass),
            signatureRequestsVerificationEmail: try int(.signatureRequestsVerificationEmail),
            signatureRequestsVerificationWhatsapp: try int(.signatureRequestsVerificationWhatsapp),
            signatureRequestsVerificationDigitalCertificate:
                try int(.signatureRequestsVerificationDigitalCertificate),
            signatureRequestsViewed: try int(.signatureRequestsViewed,
                                             legacyKey: .legacyDocumentsOpened),
            signatureRequestsCompleted: try int(.signatureRequestsCompleted,
                                                legacyKey: .legacyDocumentsSigned),
            documentsCertified:        try int(.documentsCertified)
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

    /// Creates account-statistics aggregation parameters.
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
