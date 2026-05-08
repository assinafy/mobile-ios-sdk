import Foundation

// MARK: - CreateWorkspacePayload

/// Payload for creating a new workspace (account).
@objcMembers
public final class CreateWorkspacePayload: NSObject, Encodable {
    public let name: String
    public let primaryColor: String?
    public let secondaryColor: String?

    @objc public init(name: String, primaryColor: String? = nil, secondaryColor: String? = nil) {
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }

    enum CodingKeys: String, CodingKey {
        case name
        case primaryColor   = "primary_color"
        case secondaryColor = "secondary_color"
    }
}

extension CreateWorkspacePayload: @unchecked Sendable {}

// MARK: - UpdateWorkspacePayload

/// Payload for updating an existing workspace. Only supply the fields to change.
@objcMembers
public final class UpdateWorkspacePayload: NSObject, Encodable {
    public let name: String?
    public let primaryColor: String?
    public let secondaryColor: String?

    @objc public init(
        name: String? = nil,
        primaryColor: String? = nil,
        secondaryColor: String? = nil
    ) {
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }

    enum CodingKeys: String, CodingKey {
        case name
        case primaryColor   = "primary_color"
        case secondaryColor = "secondary_color"
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
