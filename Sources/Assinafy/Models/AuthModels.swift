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
        case mfaToken = "mfa_token"
    }

    /// Throws ``MFARequiredError`` when the login answered with a two-factor
    /// challenge instead of a session.
    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if !c.contains(.accessToken), let mfaToken = try c.decodeIfPresent(String.self, forKey: .mfaToken) {
            throw MFARequiredError(mfaToken: mfaToken)
        }
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

    enum CodingKeys: String, CodingKey { case email }

    public required convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(email: try c.decodeIfPresent(String.self, forKey: .email) ?? "")
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

// MARK: - Two-factor authentication

/// Payload for ``AuthResource/verifyMFA(_:)``.
@objcMembers
public final class VerifyMFAPayload: NSObject, Encodable {
    /// The ``MFARequiredError/mfaToken`` from the login.
    public let mfaToken: String
    /// A 6-digit authenticator code, or a recovery code such as `ABCD-EFGH-JKMN`.
    public let code: String

    /// Creates the second step of a two-factor login.
    @objc public init(mfaToken: String, code: String) {
        self.mfaToken = mfaToken
        self.code = code
    }

    enum CodingKeys: String, CodingKey {
        case code
        case mfaToken = "mfa_token"
    }
}

extension VerifyMFAPayload: @unchecked Sendable {}

/// An enrolled two-factor method.
@objcMembers
public final class MFAMethod: NSObject {
    public let id: String
    /// Method type, such as `Totp`.
    public let type: String
    public let label: String?
    public let confirmedAt: String?
    public let lastUsedAt: String?

    init(id: String, type: String, label: String?, confirmedAt: String?, lastUsedAt: String?) {
        self.id = id; self.type = type; self.label = label
        self.confirmedAt = confirmedAt; self.lastUsedAt = lastUsedAt
    }
}

extension MFAMethod: @unchecked Sendable {}

extension MFAMethod: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, type, label
        case confirmedAt = "confirmed_at"
        case lastUsedAt  = "last_used_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:          try c.decode(String.self, forKey: .id),
            type:        try c.decodeIfPresent(String.self, forKey: .type) ?? "",
            label:       try c.decodeIfPresent(String.self, forKey: .label),
            confirmedAt: try decodeFlexibleOptionalString(from: c, forKey: .confirmedAt),
            lastUsedAt:  try decodeFlexibleOptionalString(from: c, forKey: .lastUsedAt)
        )
    }
}

/// The authenticated user's two-factor methods, from ``AuthResource/mfaStatus()``.
@objcMembers
public final class MFAStatus: NSObject {
    public let methods: [MFAMethod]
    /// Unused recovery codes left.
    public let recoveryCodesRemaining: Int

    init(methods: [MFAMethod], recoveryCodesRemaining: Int) {
        self.methods = methods
        self.recoveryCodesRemaining = recoveryCodesRemaining
    }
}

extension MFAStatus: @unchecked Sendable {}

extension MFAStatus: Decodable {
    enum CodingKeys: String, CodingKey {
        case methods
        case recoveryCodesRemaining = "recovery_codes_remaining"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            methods: try c.decodeIfPresent([MFAMethod].self, forKey: .methods) ?? [],
            recoveryCodesRemaining: try c.decodeIfPresent(Int.self, forKey: .recoveryCodesRemaining) ?? 0
        )
    }
}

/// An unconfirmed authenticator enrollment from ``AuthResource/enrollTOTP(label:)``.
///
/// The ``secret`` is returned only once. Show ``provisioningURI`` as a QR code, then
/// confirm with ``AuthResource/confirmTOTP(_:)``.
@objcMembers
public final class TOTPEnrollment: NSObject {
    /// Method ID to pass to ``ConfirmTOTPPayload``.
    public let id: String
    /// Base32 shared secret.
    public let secret: String
    /// `otpauth://` URI for authenticator apps.
    public let provisioningURI: String

    init(id: String, secret: String, provisioningURI: String) {
        self.id = id; self.secret = secret; self.provisioningURI = provisioningURI
    }
}

extension TOTPEnrollment: @unchecked Sendable {}

extension TOTPEnrollment: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, secret
        case provisioningURI = "provisioning_uri"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:              try c.decode(String.self, forKey: .id),
            secret:          try c.decode(String.self, forKey: .secret),
            provisioningURI: try c.decodeIfPresent(String.self, forKey: .provisioningURI) ?? ""
        )
    }
}

/// Payload for ``AuthResource/confirmTOTP(_:)``.
///
/// Replacing an already confirmed authenticator also requires `password` or
/// `reauthCode` (a live code from the current device, or a recovery code).
/// First-time enrollment needs neither.
@objcMembers
public final class ConfirmTOTPPayload: NSObject, Encodable {
    /// The ``TOTPEnrollment/id``.
    public let id: String
    /// A live code from the new device.
    public let code: String
    public let password: String?
    public let reauthCode: String?

    /// Creates an enrollment confirmation.
    @objc public init(id: String, code: String, password: String? = nil, reauthCode: String? = nil) {
        self.id = id; self.code = code
        self.password = password; self.reauthCode = reauthCode
    }

    enum CodingKeys: String, CodingKey {
        case id, code, password
        case reauthCode = "reauth_code"
    }
}

extension ConfirmTOTPPayload: @unchecked Sendable {}

/// Re-authentication proof for ``AuthResource/regenerateRecoveryCodes(_:)`` and
/// ``AuthResource/removeMFAMethod(id:_:)``: the current password, a live
/// authenticator code, or an existing recovery code (which is consumed).
@objcMembers
public final class MFAReauthPayload: NSObject, Encodable {
    public let password: String?
    public let code: String?

    /// Creates a re-authentication proof; set `password`, `code`, or both.
    @objc public init(password: String? = nil, code: String? = nil) {
        self.password = password
        self.code = code
    }
}

extension MFAReauthPayload: @unchecked Sendable {}

/// `{ "recovery_codes": [...] }`.
struct MFARecoveryCodes: Decodable, Sendable {
    let recoveryCodes: [String]
    enum CodingKeys: String, CodingKey { case recoveryCodes = "recovery_codes" }
}

/// `{ "is_mfa_enabled": bool }`.
struct MFAEnabledState: Decodable, Sendable {
    let isMfaEnabled: Bool
    enum CodingKeys: String, CodingKey { case isMfaEnabled = "is_mfa_enabled" }
}

/// `{ "label": string }` for ``AuthResource/enrollTOTP(label:)``.
struct EnrollTOTPBody: Encodable, Sendable {
    let label: String?
}
