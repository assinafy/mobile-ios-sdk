import Foundation

/// Workspace notification rules. Disabled events override each member’s preferences.
@objcMembers
public final class NotificationPolicy: NSObject, Decodable {
    /// Whether the requesting user may change this policy.
    public let editable: Bool
    /// Owners receive push alerts for every member’s documents, subject to their preferences.
    public let ownersReceiveAll: Bool
    /// Notification codes. Identity-review email is always sent.
    public let events: [String: Bool]

    enum CodingKeys: String, CodingKey {
        case editable
        case ownersReceiveAll = "owners_receive_all"
        case events
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        editable = try c.decodeIfPresent(Bool.self, forKey: .editable) ?? false
        ownersReceiveAll = try c.decodeIfPresent(Bool.self, forKey: .ownersReceiveAll) ?? false
        events = try c.decodeIfPresent([String: Bool].self, forKey: .events) ?? [:]
    }
}

extension NotificationPolicy: @unchecked Sendable {}

/// Partial policy update. Omitted fields retain their server values.
@objcMembers
public final class UpdateNotificationPolicyPayload: NSObject, Encodable {
    public let events: [String: Bool]?
    public let ownersReceiveAll: NSNumber?

    public init(events: [String: Bool]? = nil, ownersReceiveAll: NSNumber? = nil) {
        self.events = events
        self.ownersReceiveAll = ownersReceiveAll
    }

    enum CodingKeys: String, CodingKey {
        case events
        case ownersReceiveAll = "owners_receive_all"
    }

    public func encode(to encoder: Encoder) throws {
        guard events?.isEmpty == false || ownersReceiveAll != nil else {
            throw ValidationError("At least one notification policy setting is required")
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(events, forKey: .events)
        if let ownersReceiveAll { try c.encode(ownersReceiveAll.boolValue, forKey: .ownersReceiveAll) }
    }
}

extension UpdateNotificationPolicyPayload: @unchecked Sendable {}
