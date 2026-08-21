import Foundation

// MARK: - Tag

/// Workspace-scoped label that can be attached to documents and templates.
///
/// Full tag responses include timestamps. Inline tag responses embedded in
/// document and template payloads usually include only `id`, `name`, and
/// `color`.
@objcMembers
public final class Tag: NSObject {
    /// Resource discriminator returned by the API when present.
    public let resource: String?
    public let id: String
    public let name: String
    public let color: String?
    public let createdAt: String?
    public let updatedAt: String?

    init(resource: String? = nil, id: String, name: String, color: String? = nil,
         createdAt: String? = nil, updatedAt: String? = nil) {
        self.resource = resource
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Tag: @unchecked Sendable {}

extension Tag: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, name, color
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            resource: try c.decodeIfPresent(String.self, forKey: .resource),
            id: try c.decode(String.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            color: try c.decodeIfPresent(String.self, forKey: .color),
            createdAt: try decodeFlexibleOptionalString(from: c, forKey: .createdAt),
            updatedAt: try decodeFlexibleOptionalString(from: c, forKey: .updatedAt)
        )
    }
}

// MARK: - Tag Payloads

/// Query parameters for listing workspace tags.
@objcMembers
public final class TagListParams: NSObject {
    public var search: String?

    /// Creates an optional free-text tag search.
    @objc public init(search: String? = nil) {
        self.search = search
    }

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let search, !search.isEmpty {
            items.append(.init(name: "search", value: search))
        }
        return items
    }
}

extension TagListParams: @unchecked Sendable {}

/// Payload for `POST /accounts/{account_id}/tags`.
@objcMembers
public final class CreateTagPayload: NSObject, Encodable {
    public let name: String
    public let color: String?

    /// Creates a tag with an optional color value.
    @objc public init(name: String, color: String? = nil) {
        self.name = name
        self.color = color
    }
}

extension CreateTagPayload: @unchecked Sendable {}

/// Payload for `PUT /accounts/{account_id}/tags/{tag_id}`.
@objcMembers
public final class UpdateTagPayload: NSObject, Encodable {
    public let name: String?
    public let color: String?
    public let clearsColor: Bool

    /// Creates a tag update payload.
    ///
    /// - Parameters:
    ///   - name: New tag name, or `nil` to leave unchanged.
    ///   - color: New 6-character hex color, with or without `#`.
    ///   - clearsColor: Encodes `color: null` when `true`.
    @objc public init(name: String? = nil, color: String? = nil, clearsColor: Bool = false) {
        self.name = name
        self.color = color
        self.clearsColor = clearsColor
    }

    enum CodingKeys: String, CodingKey {
        case name, color
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        if clearsColor {
            try c.encodeNil(forKey: .color)
        } else {
            try c.encodeIfPresent(color, forKey: .color)
        }
    }
}

extension UpdateTagPayload: @unchecked Sendable {}

struct TagNamesPayload: Encodable {
    let tags: [String]
}

struct TagDeleteResponse: Decodable {
    let deleted: Bool?
}

struct TagDetachResponse: Decodable {
    let detached: Bool?
}
