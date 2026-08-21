import Foundation

// MARK: - TemplateRole

/// A named role defined within a document template.
@objcMembers
public final class TemplateRole: NSObject {
    public let id: String
    public let name: String
    public let assignmentType: String?
    public let createdAt: String?
    public let updatedAt: String?

    init(id: String, name: String, assignmentType: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.id = id; self.name = name
        self.assignmentType = assignmentType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension TemplateRole: @unchecked Sendable {}

extension TemplateRole: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name
        case assignmentType = "assignment_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:   try c.decode(String.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            assignmentType: try c.decodeIfPresent(String.self, forKey: .assignmentType),
            createdAt: try decodeFlexibleOptionalString(from: c, forKey: .createdAt),
            updatedAt: try decodeFlexibleOptionalString(from: c, forKey: .updatedAt)
        )
    }
}

// MARK: - TemplateFieldPlacement

/// Field placement configured on a template page.
@objcMembers
public final class TemplateFieldPlacement: NSObject {
    public let id: String
    public let fieldId: String
    public let roleId: String
    public let label: String?
    public let displaySettings: String?
    public let createdAt: String?
    public let updatedAt: String?

    init(id: String, fieldId: String, roleId: String, label: String? = nil,
         displaySettings: String? = nil, createdAt: String? = nil, updatedAt: String? = nil) {
        self.id = id
        self.fieldId = fieldId
        self.roleId = roleId
        self.label = label
        self.displaySettings = displaySettings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension TemplateFieldPlacement: @unchecked Sendable {}

extension TemplateFieldPlacement: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, label
        case fieldId = "field_id"
        case roleId = "role_id"
        case displaySettings = "display_settings"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            fieldId: try c.decode(String.self, forKey: .fieldId),
            roleId: try c.decode(String.self, forKey: .roleId),
            label: try c.decodeIfPresent(String.self, forKey: .label),
            displaySettings: try decodeFlexibleOptionalString(from: c, forKey: .displaySettings),
            createdAt: try decodeFlexibleOptionalString(from: c, forKey: .createdAt),
            updatedAt: try decodeFlexibleOptionalString(from: c, forKey: .updatedAt)
        )
    }
}

// MARK: - TemplatePage

/// Rendered page metadata for a template.
@objcMembers
public final class TemplatePage: NSObject {
    public let id: String
    public let number: Int
    public let height: Int
    public let width: Int
    public let downloadUrl: String
    public let fields: [TemplateFieldPlacement]

    init(id: String, number: Int, height: Int, width: Int,
         downloadUrl: String, fields: [TemplateFieldPlacement] = []) {
        self.id = id
        self.number = number
        self.height = height
        self.width = width
        self.downloadUrl = downloadUrl
        self.fields = fields
    }
}

extension TemplatePage: @unchecked Sendable {}

extension TemplatePage: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, number, height, width, fields
        case downloadUrl = "download_url"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            number: try c.decode(Int.self, forKey: .number),
            height: try c.decode(Int.self, forKey: .height),
            width: try c.decode(Int.self, forKey: .width),
            downloadUrl: try c.decode(String.self, forKey: .downloadUrl),
            fields: (try? c.decode([TemplateFieldPlacement].self, forKey: .fields)) ?? []
        )
    }
}

// MARK: - TemplateListItem

/// A template summary item in a paginated list response.
@objcMembers
public final class TemplateListItem: NSObject {
    /// Resource discriminator returned by the API when present.
    public let resource: String?
    public let id: String
    public let name: String
    /// Default document name applied when instantiating documents from this template.
    public let documentName: String?
    /// Default invitation message attached to documents instantiated from this template.
    public let message: String?
    public let status: String
    public let accountId: String?
    public let createdAt: String
    public let updatedAt: String?
    public let pages: [TemplatePage]
    public let roles: [TemplateRole]
    public let tags: [Tag]

    init(resource: String? = nil, id: String, name: String,
         documentName: String? = nil, message: String? = nil,
         status: String, accountId: String? = nil,
         createdAt: String, updatedAt: String? = nil,
         pages: [TemplatePage] = [], roles: [TemplateRole] = [], tags: [Tag] = []) {
        self.resource = resource
        self.id = id; self.name = name
        self.documentName = documentName; self.message = message
        self.status = status
        self.accountId = accountId; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.pages = pages; self.roles = roles; self.tags = tags
    }
}

extension TemplateListItem: @unchecked Sendable {}

extension TemplateListItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, name, message, status, pages, roles, tags
        case documentName = "document_name"
        case accountId = "account_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            resource:     try c.decodeIfPresent(String.self, forKey: .resource),
            id:           try c.decode(String.self,          forKey: .id),
            name:         try c.decode(String.self,          forKey: .name),
            documentName: try c.decodeIfPresent(String.self, forKey: .documentName),
            message:      try c.decodeIfPresent(String.self, forKey: .message),
            status:       try c.decode(String.self,          forKey: .status),
            accountId:    try c.decodeIfPresent(String.self, forKey: .accountId),
            createdAt:    try decodeFlexibleString(from: c, forKey: .createdAt),
            updatedAt:    try decodeFlexibleOptionalString(from: c, forKey: .updatedAt),
            pages:        (try? c.decode([TemplatePage].self, forKey: .pages)) ?? [],
            roles:        (try? c.decode([TemplateRole].self, forKey: .roles)) ?? [],
            tags:         (try? c.decode([Tag].self, forKey: .tags)) ?? []
        )
    }
}

// MARK: - TemplateDetails

/// Full template details, including role definitions.
@objcMembers
public final class TemplateDetails: NSObject {
    /// Resource discriminator returned by the API.
    public let resource: String?
    public let id: String
    public let name: String
    public let status: String
    public let accountId: String?
    /// Default document name applied when instantiating documents from this template.
    public let documentName: String?
    /// Default invitation message attached to documents instantiated from this template.
    public let message: String?
    public let roles: [TemplateRole]?
    public let pages: [TemplatePage]
    public let tags: [Tag]
    public let defaultDocumentTags: [Tag]
    public let createdAt: String
    public let updatedAt: String?

    init(resource: String? = nil, id: String, name: String, status: String, accountId: String? = nil,
         documentName: String? = nil, message: String? = nil,
         roles: [TemplateRole]? = nil, pages: [TemplatePage] = [], tags: [Tag] = [],
         defaultDocumentTags: [Tag] = [], createdAt: String, updatedAt: String? = nil) {
        self.resource = resource
        self.id = id; self.name = name; self.status = status
        self.accountId = accountId
        self.documentName = documentName; self.message = message
        self.roles = roles
        self.pages = pages
        self.tags = tags
        self.defaultDocumentTags = defaultDocumentTags
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

extension TemplateDetails: @unchecked Sendable {}

extension TemplateDetails: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, name, status, roles, message, pages, tags
        case accountId = "account_id"
        case documentName = "document_name"
        case defaultDocumentTags = "default_document_tags"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            resource:     try c.decodeIfPresent(String.self,          forKey: .resource),
            id:           try c.decode(String.self,                  forKey: .id),
            name:         try c.decode(String.self,                  forKey: .name),
            status:       try c.decode(String.self,                  forKey: .status),
            accountId:    try c.decodeIfPresent(String.self,         forKey: .accountId),
            documentName: try c.decodeIfPresent(String.self,         forKey: .documentName),
            message:      try c.decodeIfPresent(String.self,         forKey: .message),
            roles:        try c.decodeIfPresent([TemplateRole].self, forKey: .roles),
            pages:        (try? c.decode([TemplatePage].self, forKey: .pages)) ?? [],
            tags:         (try? c.decode([Tag].self, forKey: .tags)) ?? [],
            defaultDocumentTags: (try? c.decode([Tag].self, forKey: .defaultDocumentTags)) ?? [],
            createdAt:    try decodeFlexibleString(from: c, forKey: .createdAt),
            updatedAt:    try decodeFlexibleOptionalString(from: c, forKey: .updatedAt)
        )
    }
}

// MARK: - TemplateSigner

/// Maps a signer to a template role when creating a document from a template.
@objcMembers
public final class TemplateSigner: NSObject, Encodable {
    public let roleId: String
    public let id: String?
    public let verificationMethod: String?
    public let notificationMethods: [String]?
    public let step: NSNumber?

    /// Creates a signer-to-role mapping for template document creation.
    /// - Parameters:
    ///   - roleId: Template role ID.
    ///   - id: Signer ID; required when creating a document.
    ///   - verificationMethod: Optional verification method.
    ///   - notificationMethods: Optional notification channels.
    ///   - step: Optional one-based signing order.
    @objc public init(
        roleId: String,
        id: String? = nil,
        verificationMethod: String? = nil,
        notificationMethods: [String]? = nil,
        step: NSNumber? = nil
    ) {
        self.roleId = roleId; self.id = id
        self.verificationMethod = verificationMethod
        self.notificationMethods = notificationMethods
        self.step = step
    }

    enum CodingKeys: String, CodingKey {
        case id
        case roleId              = "role_id"
        case verificationMethod  = "verification_method"
        case notificationMethods = "notification_methods"
        case step
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(roleId, forKey: .roleId)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(verificationMethod, forKey: .verificationMethod)
        try c.encodeIfPresent(notificationMethods, forKey: .notificationMethods)
        if let step { try c.encode(step.intValue, forKey: .step) }
    }
}

extension TemplateSigner: @unchecked Sendable {}

extension TemplateSigner {
    /// Validates the fields required when actually creating a document.
    func validateForDocumentCreation() throws {
        try validateRoleId()
        guard let id, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Signer ID is required for template document creation")
        }
    }

    /// Builds the narrower signer object accepted by the cost-estimate endpoint.
    /// Signer IDs and signing steps are intentionally omitted from this payload.
    func costEstimatePayload() throws -> TemplateSignerCostEstimatePayload {
        try validateRoleId()
        return TemplateSignerCostEstimatePayload(
            roleId: roleId,
            verificationMethod: verificationMethod,
            notificationMethods: notificationMethods
        )
    }

    private func validateRoleId() throws {
        guard !roleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Template role ID is required")
        }
    }
}

/// Internal request shape for template cost estimates.
struct TemplateSignerCostEstimatePayload: Encodable, Sendable {
    let roleId: String
    let verificationMethod: String?
    let notificationMethods: [String]?

    enum CodingKeys: String, CodingKey {
        case roleId = "role_id"
        case verificationMethod = "verification_method"
        case notificationMethods = "notification_methods"
    }
}

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

    /// Creates a partial template update; omitted values remain unchanged.
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
    public var editorFields: [TemplateEditorField]
    public var tags: [String]

    /// Creates options for a document instantiated from a template.
    @objc public init(
        name: String? = nil,
        message: String? = nil,
        expiresAt: String? = nil,
        editorFields: [TemplateEditorField] = [],
        tags: [String] = []
    ) {
        self.name = name; self.message = message; self.expiresAt = expiresAt
        self.editorFields = editorFields
        self.tags = tags
    }
}

extension CreateDocumentFromTemplateOptions: @unchecked Sendable {}

// MARK: - TemplateListParams

/// Query parameters for `GET /accounts/{account_id}/templates`.
@objcMembers
public final class TemplateListParams: NSObject {
    /// Live-verified sandbox extension; not present in production OpenAPI.
    public var status: String?
    public var search: String?
    /// Live-verified sandbox extension; not present in production OpenAPI.
    public var tagIds: [String]
    /// Legacy server extension retained for compatibility.
    public var sort: String?
    public var page: Int
    public var perPage: Int

    /// Creates legacy template-list filters retained for compatibility.
    @objc public init(
        status: String? = nil,
        search: String? = nil,
        tagIds: [String] = [],
        sort: String? = nil
    ) {
        self.status = status
        self.search = search
        self.tagIds = tagIds
        self.sort = sort
        self.page = 0
        self.perPage = 0
    }

    /// Creates documented template-list parameters plus optional compatibility filters.
    @objc(initWithStatus:search:tagIds:sort:page:perPage:)
    public init(
        status: String? = nil,
        search: String? = nil,
        tagIds: [String] = [],
        sort: String? = nil,
        page: Int,
        perPage: Int
    ) {
        self.status = status
        self.search = search
        self.tagIds = tagIds
        self.sort = sort
        self.page = page
        self.perPage = perPage
    }

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let status, !status.isEmpty { items.append(.init(name: "status", value: status)) }
        if let search, !search.isEmpty { items.append(.init(name: "search", value: search)) }
        if !tagIds.isEmpty { items.append(.init(name: "tags", value: tagIds.joined(separator: ","))) }
        if let sort, !sort.isEmpty { items.append(.init(name: "sort", value: sort)) }
        if page > 0 { items.append(.init(name: "page", value: "\(page)")) }
        if perPage > 0 { items.append(.init(name: "per-page", value: "\(perPage)")) }
        return items
    }
}

extension TemplateListParams: @unchecked Sendable {}

// MARK: - TemplateEditorField

/// Editor-field value supplied when creating a document from a template.
@objcMembers
public final class TemplateEditorField: NSObject, Encodable {
    public let fieldId: String
    public let value: String

    /// Creates one template editor-field value.
    @objc public init(fieldId: String, value: String) {
        self.fieldId = fieldId
        self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case value
    }
}

extension TemplateEditorField: @unchecked Sendable {}
