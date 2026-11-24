import Foundation

/// An assignment or envelope kept for later sending. Scheduling does not reserve documents or credits.
@objcMembers
public final class ScheduledSend: NSObject, Decodable {
    /// Scheduled send ID, used to cancel or send a pending request.
    public let id: String
    /// `assignment` or `envelope`; future values are preserved.
    public let type: String
    /// Documents included in the saved request.
    public let documentIds: [String]
    /// `pending`, `processing`, `sent`, `cancelled`, or `failed`.
    public let status: String
    /// ISO-8601 planned send time. Due sends are processed every five minutes.
    public let sendAt: String
    /// Assignment created by a successful assignment send.
    public let assignmentId: String?
    /// Envelope created by a successful envelope send.
    public let envelopeId: String?
    /// Reason a background send failed; nil otherwise.
    public let failureReason: String?
    /// ISO-8601 creation time.
    public let createdAt: String
    /// ISO-8601 processing time, or nil while pending.
    public let processedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type, status
        case documentIds = "document_ids", sendAt = "send_at"
        case assignmentId = "assignment_id", envelopeId = "envelope_id"
        case failureReason = "failure_reason", createdAt = "created_at", processedAt = "processed_at"
    }
}

extension ScheduledSend: @unchecked Sendable {}

/// Adds the send time without round-tripping assignment or envelope decimals through JSONSerialization.
struct ScheduledSendBody<Payload: Encodable>: Encodable {
    let payload: Payload
    let sendAt: Date

    enum CodingKeys: String, CodingKey { case sendAt = "send_at" }

    func encode(to encoder: Encoder) throws {
        guard sendAt.timeIntervalSince1970.isFinite else {
            throw ValidationError("Scheduled send time must be a finite date")
        }
        try payload.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ISO8601DateFormatter().string(from: sendAt), forKey: .sendAt)
    }
}
