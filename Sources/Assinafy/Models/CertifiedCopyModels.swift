import Foundation

/// Availability and delivery of a signer’s certified copy.
@objcMembers
public final class CertifiedCopy: NSObject, Decodable {
    /// Whether another copy can be requested.
    public let available: Bool
    /// Original notification channel: Email or Whatsapp.
    public let notificationMethod: String?
    /// Remaining WhatsApp resends; nil for email.
    public let resendsLeft: NSNumber?
    /// Masked original contact after delivery.
    public let sentTo: String?

    enum CodingKeys: String, CodingKey {
        case available
        case notificationMethod = "notification_method"
        case resendsLeft = "resends_left"
        case sentTo = "sent_to"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        available = try c.decodeIfPresent(Bool.self, forKey: .available) ?? false
        notificationMethod = try c.decodeIfPresent(String.self, forKey: .notificationMethod)
        resendsLeft = try c.decodeIfPresent(Int.self, forKey: .resendsLeft).map { NSNumber(value: $0) }
        sentTo = try c.decodeIfPresent(String.self, forKey: .sentTo)
    }
}

extension CertifiedCopy: @unchecked Sendable {}
