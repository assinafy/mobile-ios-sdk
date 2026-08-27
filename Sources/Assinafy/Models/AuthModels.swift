import Foundation

// MARK: - Account

/// Account summary returned by authentication endpoints.
@objcMembers
public final class Account: NSObject {
    public let id: String
    public let name: String
    public let roles: [String]
    public let isDeleteAllowed: Bool
    public let createdAt: String

    init(id: String, name: String, roles: [String], isDeleteAllowed: Bool, createdAt: String) {
        self.id = id
        self.name = name
        self.roles = roles
        self.isDeleteAllowed = isDeleteAllowed
        self.createdAt = createdAt
    }
}

extension Account: @unchecked Sendable {}

extension Account: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, roles
        case isDeleteAllowed = "is_delete_allowed"
        case createdAt = "created_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            roles: try c.decodeIfPresent([String].self, forKey: .roles) ?? [],
            isDeleteAllowed: try c.decodeIfPresent(Bool.self, forKey: .isDeleteAllowed) ?? false,
            createdAt: try c.decode(String.self, forKey: .createdAt)
        )
    }
}

// MARK: - User

/// User profile returned by login and social-login endpoints.
@objcMembers
public final class User: NSObject {
    public let id: String
    public let name: String
    public let email: String
    public let telephone: String?
    public let governmentId: String?
    public let isEmailVerified: Bool
    public let hasAcceptedTerms: Bool
    /// Whether the user has a password set (returned by `GET /users/self`).
    public let isPasswordSet: Bool
    public let createdAt: String
    public let toBeDeletedAt: String?

    init(
        id: String,
        name: String,
        email: String,
        telephone: String? = nil,
        governmentId: String? = nil,
        isEmailVerified: Bool = false,
        hasAcceptedTerms: Bool = false,
        isPasswordSet: Bool = false,
        createdAt: String,
        toBeDeletedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.telephone = telephone
        self.governmentId = governmentId
        self.isEmailVerified = isEmailVerified
        self.hasAcceptedTerms = hasAcceptedTerms
        self.isPasswordSet = isPasswordSet
        self.createdAt = createdAt
        self.toBeDeletedAt = toBeDeletedAt
    }
}

extension User: @unchecked Sendable {}

extension User: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, email, telephone
        case governmentId = "government_id"
        case isEmailVerified = "is_email_verified"
        case hasAcceptedTerms = "has_accepted_terms"
        case isPasswordSet = "is_password_set"
        case createdAt = "created_at"
        case toBeDeletedAt = "to_be_deleted_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            email: try c.decode(String.self, forKey: .email),
            telephone: try c.decodeIfPresent(String.self, forKey: .telephone),
            governmentId: try c.decodeIfPresent(String.self, forKey: .governmentId),
            isEmailVerified: try c.decodeIfPresent(Bool.self, forKey: .isEmailVerified) ?? false,
            hasAcceptedTerms: try c.decodeIfPresent(Bool.self, forKey: .hasAcceptedTerms) ?? false,
            isPasswordSet: try c.decodeIfPresent(Bool.self, forKey: .isPasswordSet) ?? false,
            createdAt: try c.decode(String.self, forKey: .createdAt),
            toBeDeletedAt: try c.decodeIfPresent(String.self, forKey: .toBeDeletedAt)
        )
    }
}

// MARK: - LoginResponse

/// Response returned by login and social-login endpoints.
@objcMembers
public final class LoginResponse: NSObject {
    public let accessToken: String
    public let user: User
    public let accounts: [Account]

    init(accessToken: String, user: User, accounts: [Account]) {
        self.accessToken = accessToken
        self.user = user
        self.accounts = accounts
    }
}

extension LoginResponse: @unchecked Sendable {}

extension LoginResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
        case accounts
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            accessToken: try c.decode(String.self, forKey: .accessToken),
            user: try c.decode(User.self, forKey: .user),
            accounts: try c.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        )
    }
}

// MARK: - SelfResponse

/// The authenticated user's profile returned by `GET /users/self`.
///
/// The current API returns the user directly. ``accounts`` is retained for
/// source compatibility with older responses that wrapped `{ user, accounts }`.
@objcMembers
public final class SelfResponse: NSObject {
    public let user: User
    public let accounts: [Account]

    init(user: User, accounts: [Account]) {
        self.user = user
        self.accounts = accounts
    }
}

extension SelfResponse: @unchecked Sendable {}

extension SelfResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case user, accounts
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let user = try c.decodeIfPresent(User.self, forKey: .user) {
            self.init(
                user: user,
                accounts: try c.decodeIfPresent([Account].self, forKey: .accounts) ?? []
            )
            return
        }
        self.init(
            user: try User(from: decoder),
            accounts: []
        )
    }
}

// MARK: - EmailResponse

/// Email payload returned after password-change and password-reset operations.
@objcMembers
public final class EmailResponse: NSObject, Decodable {
    /// The account email affected by the operation.
    public let email: String

    /// Creates a password-operation response.
    /// - Parameter email: The account email returned by the API.
    public init(email: String) {
        self.email = email
    }
}

extension EmailResponse: @unchecked Sendable {}

// MARK: - Notification Preferences

private enum NotificationPreferenceCodingKeys: String, CodingKey {
    case documentCompleted = "DocumentCompleted"
    case signerDeclined = "SignerDeclined"
    case documentCancelled = "DocumentCancelled"
    case documentAboutToExpire = "DocumentAboutToExpire"
    case documentExpired = "DocumentExpired"
    case documentExpirationReset = "DocumentExpirationReset"
    case documentProcessingFailed = "DocumentProcessingFailed"
    case templateProcessingFailed = "TemplateProcessingFailed"
    case signerWhatsappFailed = "SignerWhatsappFailed"
}

/// The authenticated user's owner-notification preferences.
///
/// All nine fields are returned by `GET /users/self/notification-preferences`.
@objcMembers
public final class NotificationPreferences: NSObject, Decodable {
    public let documentCompleted: Bool
    public let signerDeclined: Bool
    public let documentCancelled: Bool
    public let documentAboutToExpire: Bool
    public let documentExpired: Bool
    public let documentExpirationReset: Bool
    public let documentProcessingFailed: Bool
    public let templateProcessingFailed: Bool
    public let signerWhatsappFailed: Bool

    /// Creates a complete owner-notification preference value.
    /// - Parameters:
    ///   - documentCompleted: Notify when a document completes.
    ///   - signerDeclined: Notify when a signer declines.
    ///   - documentCancelled: Notify when a document is cancelled.
    ///   - documentAboutToExpire: Notify shortly before expiration.
    ///   - documentExpired: Notify when a document expires.
    ///   - documentExpirationReset: Notify when expiration is reset.
    ///   - documentProcessingFailed: Notify when document processing fails.
    ///   - templateProcessingFailed: Notify when template processing fails.
    ///   - signerWhatsappFailed: Notify when signer WhatsApp delivery fails.
    public init(
        documentCompleted: Bool,
        signerDeclined: Bool,
        documentCancelled: Bool,
        documentAboutToExpire: Bool,
        documentExpired: Bool,
        documentExpirationReset: Bool,
        documentProcessingFailed: Bool,
        templateProcessingFailed: Bool,
        signerWhatsappFailed: Bool
    ) {
        self.documentCompleted = documentCompleted
        self.signerDeclined = signerDeclined
        self.documentCancelled = documentCancelled
        self.documentAboutToExpire = documentAboutToExpire
        self.documentExpired = documentExpired
        self.documentExpirationReset = documentExpirationReset
        self.documentProcessingFailed = documentProcessingFailed
        self.templateProcessingFailed = templateProcessingFailed
        self.signerWhatsappFailed = signerWhatsappFailed
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: NotificationPreferenceCodingKeys.self)
        self.init(
            documentCompleted: try c.decode(Bool.self, forKey: .documentCompleted),
            signerDeclined: try c.decode(Bool.self, forKey: .signerDeclined),
            documentCancelled: try c.decode(Bool.self, forKey: .documentCancelled),
            documentAboutToExpire: try c.decode(Bool.self, forKey: .documentAboutToExpire),
            documentExpired: try c.decode(Bool.self, forKey: .documentExpired),
            documentExpirationReset: try c.decode(Bool.self, forKey: .documentExpirationReset),
            documentProcessingFailed: try c.decode(Bool.self, forKey: .documentProcessingFailed),
            templateProcessingFailed: try c.decode(Bool.self, forKey: .templateProcessingFailed),
            signerWhatsappFailed: try c.decode(Bool.self, forKey: .signerWhatsappFailed)
        )
    }
}

extension NotificationPreferences: @unchecked Sendable {}

/// Partial update for `PUT /users/self/notification-preferences`.
///
/// Set only the preferences to change; omitted fields retain their server value.
@objcMembers
public final class UpdateNotificationPreferencesPayload: NSObject, Encodable {
    public let documentCompleted: NSNumber?
    public let signerDeclined: NSNumber?
    public let documentCancelled: NSNumber?
    public let documentAboutToExpire: NSNumber?
    public let documentExpired: NSNumber?
    public let documentExpirationReset: NSNumber?
    public let documentProcessingFailed: NSNumber?
    public let templateProcessingFailed: NSNumber?
    public let signerWhatsappFailed: NSNumber?

    /// Creates a partial notification-preference update; `nil` values are omitted.
    public init(
        documentCompleted: NSNumber? = nil,
        signerDeclined: NSNumber? = nil,
        documentCancelled: NSNumber? = nil,
        documentAboutToExpire: NSNumber? = nil,
        documentExpired: NSNumber? = nil,
        documentExpirationReset: NSNumber? = nil,
        documentProcessingFailed: NSNumber? = nil,
        templateProcessingFailed: NSNumber? = nil,
        signerWhatsappFailed: NSNumber? = nil
    ) {
        self.documentCompleted = documentCompleted
        self.signerDeclined = signerDeclined
        self.documentCancelled = documentCancelled
        self.documentAboutToExpire = documentAboutToExpire
        self.documentExpired = documentExpired
        self.documentExpirationReset = documentExpirationReset
        self.documentProcessingFailed = documentProcessingFailed
        self.templateProcessingFailed = templateProcessingFailed
        self.signerWhatsappFailed = signerWhatsappFailed
    }

    var isEmpty: Bool {
        documentCompleted == nil && signerDeclined == nil && documentCancelled == nil
            && documentAboutToExpire == nil && documentExpired == nil
            && documentExpirationReset == nil && documentProcessingFailed == nil
            && templateProcessingFailed == nil && signerWhatsappFailed == nil
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: NotificationPreferenceCodingKeys.self)
        if let value = documentCompleted { try c.encode(value.boolValue, forKey: .documentCompleted) }
        if let value = signerDeclined { try c.encode(value.boolValue, forKey: .signerDeclined) }
        if let value = documentCancelled { try c.encode(value.boolValue, forKey: .documentCancelled) }
        if let value = documentAboutToExpire { try c.encode(value.boolValue, forKey: .documentAboutToExpire) }
        if let value = documentExpired { try c.encode(value.boolValue, forKey: .documentExpired) }
        if let value = documentExpirationReset { try c.encode(value.boolValue, forKey: .documentExpirationReset) }
        if let value = documentProcessingFailed { try c.encode(value.boolValue, forKey: .documentProcessingFailed) }
        if let value = templateProcessingFailed { try c.encode(value.boolValue, forKey: .templateProcessingFailed) }
        if let value = signerWhatsappFailed { try c.encode(value.boolValue, forKey: .signerWhatsappFailed) }
    }
}

extension UpdateNotificationPreferencesPayload: @unchecked Sendable {}

// MARK: - Payloads

/// Payload for `POST /login`.
@objcMembers
public final class LoginPayload: NSObject, Encodable {
    public let email: String
    public let password: String

    /// Creates an email-and-password login payload.
    @objc public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

extension LoginPayload: @unchecked Sendable {}

/// Payload for `POST /authentication/social-login`.
@objcMembers
public final class SocialLoginPayload: NSObject, Encodable {
    public let provider: String
    public let token: String
    public let hasAcceptedTerms: Bool

    /// Creates a social-login payload.
    /// - Parameters:
    ///   - provider: Social identity provider; currently `google`.
    ///   - token: Provider-issued identity token.
    ///   - hasAcceptedTerms: Whether the user accepted Assinafy's terms.
    @objc public init(provider: String = "google", token: String, hasAcceptedTerms: Bool) {
        self.provider = provider
        self.token = token
        self.hasAcceptedTerms = hasAcceptedTerms
    }

    enum CodingKeys: String, CodingKey {
        case provider, token
        case hasAcceptedTerms = "has_accepted_terms"
    }
}

extension SocialLoginPayload: @unchecked Sendable {}

/// Payload for `PUT /authentication/change-password`.
@objcMembers
public final class ChangePasswordPayload: NSObject, Encodable {
    public let email: String
    public let password: String
    public let newPassword: String

    /// Creates a password-change payload with current and replacement credentials.
    @objc public init(email: String, password: String, newPassword: String) {
        self.email = email
        self.password = password
        self.newPassword = newPassword
    }

    enum CodingKeys: String, CodingKey {
        case email, password
        case newPassword = "new_password"
    }
}

extension ChangePasswordPayload: @unchecked Sendable {}

/// Payload for `PUT /authentication/request-password-reset`.
@objcMembers
public final class RequestPasswordResetPayload: NSObject, Encodable {
    public let email: String

    /// Creates a password-reset request for an email address.
    @objc public init(email: String) {
        self.email = email
    }
}

extension RequestPasswordResetPayload: @unchecked Sendable {}

/// Payload for `PUT /authentication/reset-password`.
@objcMembers
public final class ResetPasswordPayload: NSObject, Encodable {
    public let email: String
    public let token: String?
    public let newPassword: String

    /// Creates a password-reset completion payload.
    /// - Parameters:
    ///   - email: Account email address.
    ///   - token: Optional reset token supplied by the reset flow.
    ///   - newPassword: Replacement password.
    @objc public init(email: String, token: String? = nil, newPassword: String) {
        self.email = email
        self.token = token
        self.newPassword = newPassword
    }

    enum CodingKeys: String, CodingKey {
        case email, token
        case newPassword = "new_password"
    }
}

extension ResetPasswordPayload: @unchecked Sendable {}

/// Payload for `POST /users/api-keys`.
@objcMembers
public final class CreateAPIKeyPayload: NSObject, Encodable {
    public let password: String

    /// Creates an API-key request authenticated with the user's password.
    @objc public init(password: String) {
        self.password = password
    }
}

extension CreateAPIKeyPayload: @unchecked Sendable {}

/// Payload for `POST /auth/link-social-login`.
@objcMembers
public final class LinkSocialLoginPayload: NSObject, Encodable {
    /// The social provider. Currently only `"google"` is supported.
    public let provider: String
    /// The provider-issued token to link to the authenticated account.
    public let token: String

    /// Creates a request to link a provider-issued identity token.
    @objc public init(provider: String = "google", token: String) {
        self.provider = provider
        self.token = token
    }
}

extension LinkSocialLoginPayload: @unchecked Sendable {}

// MARK: - APIKeyResponse

struct APIKeyResponse: Decodable {
    let apiKey: String?

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
    }
}
