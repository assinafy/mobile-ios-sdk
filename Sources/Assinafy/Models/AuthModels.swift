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
            roles: (try? c.decode([String].self, forKey: .roles)) ?? [],
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
            accounts: (try? c.decode([Account].self, forKey: .accounts)) ?? []
        )
    }
}

// MARK: - Payloads

/// Payload for `POST /login`.
@objcMembers
public final class LoginPayload: NSObject, Encodable {
    public let email: String
    public let password: String

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

    @objc public init(password: String) {
        self.password = password
    }
}

extension CreateAPIKeyPayload: @unchecked Sendable {}

// MARK: - APIKeyResponse

struct APIKeyResponse: Decodable {
    let apiKey: String?

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
    }
}
