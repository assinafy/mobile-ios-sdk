import Foundation

// MARK: - TemplateRole

/// A named role defined within a document template.
@objcMembers
public final class TemplateRole: NSObject {
    public let id: String
    public let name: String

    init(id: String, name: String) {
        self.id = id; self.name = name
    }
}

extension TemplateRole: @unchecked Sendable {}

extension TemplateRole: Decodable {
    enum CodingKeys: String, CodingKey { case id, name }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:   try c.decode(String.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name)
        )
    }
}

// MARK: - TemplateListItem

/// A template summary item in a paginated list response.
@objcMembers
public final class TemplateListItem: NSObject {
    public let id: String
    public let name: String
    public let status: String
    public let accountId: String?
    public let createdAt: String
    public let updatedAt: String?

    init(id: String, name: String, status: String, accountId: String? = nil,
         createdAt: String, updatedAt: String? = nil) {
        self.id = id; self.name = name; self.status = status
        self.accountId = accountId; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

extension TemplateListItem: @unchecked Sendable {}

extension TemplateListItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, status
        case accountId = "account_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:        try c.decode(String.self,          forKey: .id),
            name:      try c.decode(String.self,          forKey: .name),
            status:    try c.decode(String.self,          forKey: .status),
            accountId: try c.decodeIfPresent(String.self, forKey: .accountId),
            createdAt: try c.decode(String.self,          forKey: .createdAt),
            updatedAt: try c.decodeIfPresent(String.self, forKey: .updatedAt)
        )
    }
}

// MARK: - TemplateDetails

/// Full template details, including role definitions.
@objcMembers
public final class TemplateDetails: NSObject {
    public let id: String
    public let name: String
    public let status: String
    public let accountId: String?
    /// Default document name applied when instantiating documents from this template.
    public let documentName: String?
    /// Default invitation message attached to documents instantiated from this template.
    public let message: String?
    public let roles: [TemplateRole]?
    public let createdAt: String
    public let updatedAt: String?

    init(id: String, name: String, status: String, accountId: String? = nil,
         documentName: String? = nil, message: String? = nil,
         roles: [TemplateRole]? = nil, createdAt: String, updatedAt: String? = nil) {
        self.id = id; self.name = name; self.status = status
        self.accountId = accountId
        self.documentName = documentName; self.message = message
        self.roles = roles
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

extension TemplateDetails: @unchecked Sendable {}

extension TemplateDetails: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, status, roles, message
        case accountId = "account_id"
        case documentName = "document_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:           try c.decode(String.self,                  forKey: .id),
            name:         try c.decode(String.self,                  forKey: .name),
            status:       try c.decode(String.self,                  forKey: .status),
            accountId:    try c.decodeIfPresent(String.self,         forKey: .accountId),
            documentName: try c.decodeIfPresent(String.self,         forKey: .documentName),
            message:      try c.decodeIfPresent(String.self,         forKey: .message),
            roles:        try c.decodeIfPresent([TemplateRole].self, forKey: .roles),
            createdAt:    try c.decode(String.self,                  forKey: .createdAt),
            updatedAt:    try c.decodeIfPresent(String.self,         forKey: .updatedAt)
        )
    }
}

// MARK: - TemplateSigner

/// Maps a signer to a template role when creating a document from a template.
@objcMembers
public final class TemplateSigner: NSObject, Encodable {
    public let roleId: String
    public let id: String
    public let verificationMethod: String?
    public let notificationMethods: [String]?

    @objc public init(
        roleId: String,
        id: String,
        verificationMethod: String? = nil,
        notificationMethods: [String]? = nil
    ) {
        self.roleId = roleId; self.id = id
        self.verificationMethod = verificationMethod
        self.notificationMethods = notificationMethods
    }

    enum CodingKeys: String, CodingKey {
        case id
        case roleId              = "role_id"
        case verificationMethod  = "verification_method"
        case notificationMethods = "notification_methods"
    }
}

extension TemplateSigner: @unchecked Sendable {}

// MARK: - UpdateTemplatePayload

/// Payload for `PUT /accounts/{accountId}/templates/{templateId}`.
///
/// Only provide the fields you wish to change; omitted fields are left
/// unchanged on the server.
@objcMembers
public final class UpdateTemplatePayload: NSObject, Encodable {
    /// Template display name.
    public let name: String?
    /// Default document name applied when creating documents from this template.
    public let documentName: String?
    /// Default invitation message sent with documents created from this template.
    public let message: String?

    @objc public init(
        name: String? = nil,
        documentName: String? = nil,
        message: String? = nil
    ) {
        self.name = name
        self.documentName = documentName
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case name, message
        case documentName = "document_name"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(documentName, forKey: .documentName)
        try c.encodeIfPresent(message, forKey: .message)
    }
}

extension UpdateTemplatePayload: @unchecked Sendable {}

// MARK: - CreateDocumentFromTemplateOptions

/// Options when creating a document from a template.
@objcMembers
public final class CreateDocumentFromTemplateOptions: NSObject {
    public var name: String?
    public var message: String?
    public var expiresAt: String?

    @objc public init(name: String? = nil, message: String? = nil, expiresAt: String? = nil) {
        self.name = name; self.message = message; self.expiresAt = expiresAt
    }
}

extension CreateDocumentFromTemplateOptions: @unchecked Sendable {}
