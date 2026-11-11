import Foundation

/// An exact origin allowed to host the workspace’s signing iframe.
@objcMembers
public final class EmbedOrigin: NSObject, Decodable {
    /// Origin registration ID.
    public let id: String
    /// Scheme, host and optional port.
    public let origin: String
    /// ISO-8601 creation time.
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case origin
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        origin = try c.decodeIfPresent(String.self, forKey: .origin) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

extension EmbedOrigin: @unchecked Sendable {}

/// A single-use iframe URL. Open within five minutes; never persist or log it.
@objcMembers
public final class EmbedSession: NSObject, Decodable {
    /// Load in an iframe on a registered origin.
    public let url: String
    /// ISO-8601 expiry time.
    public let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case url
        case expiresAt = "expires_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
    }
}

extension EmbedSession: @unchecked Sendable {}
