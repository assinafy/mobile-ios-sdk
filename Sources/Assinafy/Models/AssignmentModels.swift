import Foundation

// MARK: - AssignmentMethod

/// The signing method for an assignment.
@objc public enum AssignmentMethod: Int, Sendable {
    /// Remote electronic signature via email or WhatsApp link.
    case virtual = 0
    /// In-person field-based signature collection.
    case collect = 1
}

public extension AssignmentMethod {
    var stringValue: String {
        switch self {
        case .virtual: return "virtual"
        case .collect: return "collect"
        }
    }

    init(string: String) {
        self = string == "collect" ? .collect : .virtual
    }
}

// MARK: - AssignmentSummary

/// Aggregate signing progress for an assignment.
@objcMembers
public final class AssignmentSummary: NSObject {
    public let signerCount: Int
    public let completedCount: Int

    init(signerCount: Int, completedCount: Int) {
        self.signerCount = signerCount
        self.completedCount = completedCount
    }
}

extension AssignmentSummary: @unchecked Sendable {}

extension AssignmentSummary: Decodable {
    enum CodingKeys: String, CodingKey {
        case signerCount    = "signer_count"
        case completedCount = "completed_count"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            signerCount:    try c.decode(Int.self, forKey: .signerCount),
            completedCount: try c.decode(Int.self, forKey: .completedCount)
        )
    }
}

// MARK: - Assignment

/// A signing assignment linking a document to one or more signers.
@objcMembers
public final class Assignment: NSObject {
    public let id: String
    public let senderEmail: String?
    public let method: AssignmentMethod
    /// Raw API method string (e.g. `"virtual"`).
    public let methodString: String
    public let expiresAt: String?
    public let message: String?
    public let signers: [Signer]
    public let copyReceivers: [String]?
    public let summary: AssignmentSummary?

    init(id: String, senderEmail: String? = nil, method: AssignmentMethod, methodString: String,
         expiresAt: String? = nil, message: String? = nil, signers: [Signer] = [],
         copyReceivers: [String]? = nil, summary: AssignmentSummary? = nil) {
        self.id = id; self.senderEmail = senderEmail
        self.method = method; self.methodString = methodString
        self.expiresAt = expiresAt; self.message = message
        self.signers = signers; self.copyReceivers = copyReceivers
        self.summary = summary
    }
}

extension Assignment: @unchecked Sendable {}

extension Assignment: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, method, message, signers, summary
        case senderEmail    = "sender_email"
        case expiresAt      = "expires_at"
        case copyReceivers  = "copy_receivers"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let methodString = try c.decode(String.self, forKey: .method)
        self.init(
            id:            try c.decode(String.self,                  forKey: .id),
            senderEmail:   try c.decodeIfPresent(String.self,         forKey: .senderEmail),
            method:        AssignmentMethod(string: methodString),
            methodString:  methodString,
            expiresAt:     try c.decodeIfPresent(String.self,         forKey: .expiresAt),
            message:       try c.decodeIfPresent(String.self,         forKey: .message),
            signers:       (try? c.decode([Signer].self, forKey: .signers)) ?? [],
            copyReceivers: try c.decodeIfPresent([String].self,       forKey: .copyReceivers),
            summary:       try c.decodeIfPresent(AssignmentSummary.self, forKey: .summary)
        )
    }
}

// MARK: - SignerReference

/// A reference to a signer within an assignment payload.
///
/// Use ``id(_:)`` for a simple signer ID reference, or ``descriptor(id:verificationMethod:notificationMethods:)``
/// when you need to specify delivery channels or build cost-estimation payloads.
public enum SignerReference: Sendable {
    /// A signer identified solely by their ID.
    case id(String)
    /// A signer identified by ID and/or method descriptors for cost estimation.
    case descriptor(
        id: String? = nil,
        verificationMethod: String? = nil,
        notificationMethods: [String]? = nil
    )
}

// MARK: - AssignmentField

/// A field placement used by collect assignments.
public struct AssignmentField: Sendable {
    public var signerId: String
    public var fieldId: String
    public var displaySettings: String?

    public init(signerId: String, fieldId: String, displaySettings: String? = nil) {
        self.signerId = signerId
        self.fieldId = fieldId
        self.displaySettings = displaySettings
    }
}

// MARK: - AssignmentEntry

/// A page entry containing fields for collect assignments.
public struct AssignmentEntry: Sendable {
    public var pageId: String
    public var fields: [AssignmentField]

    public init(pageId: String, fields: [AssignmentField]) {
        self.pageId = pageId
        self.fields = fields
    }
}

// MARK: - CreateAssignmentPayload

/// Payload for creating a signing assignment.
///
/// Use ``withSignerIds(_:method:message:expiresAt:copyReceivers:)`` for the
/// common case where you already have signer ID strings.
public struct CreateAssignmentPayload: Sendable {
    public var method: AssignmentMethod
    public var signers: [SignerReference]
    public var entries: [AssignmentEntry]?
    public var message: String?
    public var expiresAt: String?
    public var copyReceivers: [String]?

    public init(
        method: AssignmentMethod = .virtual,
        signers: [SignerReference],
        entries: [AssignmentEntry]? = nil,
        message: String? = nil,
        expiresAt: String? = nil,
        copyReceivers: [String]? = nil
    ) {
        self.method = method; self.signers = signers
        self.entries = entries
        self.message = message; self.expiresAt = expiresAt
        self.copyReceivers = copyReceivers
    }

    /// Convenience initialiser for the common case of passing signer ID strings.
    public static func withSignerIds(
        _ ids: [String],
        method: AssignmentMethod = .virtual,
        message: String? = nil,
        expiresAt: String? = nil,
        copyReceivers: [String]? = nil
    ) -> CreateAssignmentPayload {
        CreateAssignmentPayload(
            method: method,
            signers: ids.map { .id($0) },
            entries: nil,
            message: message,
            expiresAt: expiresAt,
            copyReceivers: copyReceivers
        )
    }
}

// MARK: - Internal body

struct AssignmentFieldBody: Encodable {
    let signerId: String
    let fieldId: String
    let displaySettings: String?

    enum CodingKeys: String, CodingKey {
        case signerId = "signer_id"
        case fieldId = "field_id"
        case displaySettings = "display_settings"
    }
}

struct AssignmentEntryBody: Encodable {
    let pageId: String
    let fields: [AssignmentFieldBody]

    enum CodingKeys: String, CodingKey {
        case pageId = "page_id"
        case fields
    }
}

struct AssignmentSignerBody: Encodable {
    let id: String?
    let verificationMethod: String?
    let notificationMethods: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case verificationMethod = "verification_method"
        case notificationMethods = "notification_methods"
    }
}

struct AssignmentPayloadBody: Encodable {
    let method: String
    let signers: [AssignmentSignerBody]
    let entries: [AssignmentEntryBody]?
    let message: String?
    let expiresAt: String?
    let copyReceivers: [String]?

    enum CodingKeys: String, CodingKey {
        case method, signers, entries, message
        case expiresAt      = "expires_at"
        case copyReceivers  = "copy_receivers"
    }
}

func buildAssignmentBody(
    _ payload: CreateAssignmentPayload,
    allowWithoutId: Bool = false
) throws -> AssignmentPayloadBody {
    guard !payload.signers.isEmpty else {
        throw ValidationError("At least one signer is required")
    }
    let signerBodies = try payload.signers.map { ref in
        try buildSignerBody(ref, allowWithoutId: allowWithoutId)
    }
    let entryBodies: [AssignmentEntryBody]? = try payload.entries?.map { try buildEntryBody($0) }
    if payload.method == .collect, entryBodies?.isEmpty != false {
        throw ValidationError("Collect assignments require at least one entry")
    }
    return AssignmentPayloadBody(
        method: payload.method.stringValue,
        signers: signerBodies,
        entries: entryBodies,
        message: payload.message,
        expiresAt: payload.expiresAt,
        copyReceivers: payload.copyReceivers
    )
}

private func buildSignerBody(_ ref: SignerReference, allowWithoutId: Bool) throws -> AssignmentSignerBody {
    switch ref {
    case .id(let id):
        guard !id.isEmpty else { throw ValidationError("Signer ID cannot be empty") }
        return AssignmentSignerBody(id: id, verificationMethod: nil, notificationMethods: nil)
    case .descriptor(let id, let vm, let nm):
        let hasId = id?.isEmpty == false
        if !hasId, vm == nil, nm == nil, !allowWithoutId {
            throw ValidationError("Invalid signer reference: must provide id or verification_method")
        }
        return AssignmentSignerBody(id: hasId ? id : nil, verificationMethod: vm, notificationMethods: nm)
    }
}

private func buildEntryBody(_ entry: AssignmentEntry) throws -> AssignmentEntryBody {
    guard !entry.pageId.isEmpty else { throw ValidationError("Entry page ID cannot be empty") }
    guard !entry.fields.isEmpty else { throw ValidationError("Entry must contain at least one field") }
    let fields = try entry.fields.map { field in
        guard !field.signerId.isEmpty else { throw ValidationError("Field signer ID cannot be empty") }
        guard !field.fieldId.isEmpty else { throw ValidationError("Field ID cannot be empty") }
        return AssignmentFieldBody(signerId: field.signerId, fieldId: field.fieldId, displaySettings: field.displaySettings)
    }
    return AssignmentEntryBody(pageId: entry.pageId, fields: fields)
}

// MARK: - ResendNotificationResponse

/// Response returned when a signing notification is resent.
@objcMembers
public final class ResendNotificationResponse: NSObject {
    public let isSent: Bool
    public let documentId: String?
    public let signerId: String?

    init(isSent: Bool, documentId: String? = nil, signerId: String? = nil) {
        self.isSent = isSent; self.documentId = documentId; self.signerId = signerId
    }
}

extension ResendNotificationResponse: @unchecked Sendable {}

extension ResendNotificationResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case isSent    = "is_sent"
        case documentId = "document_id"
        case signerId   = "signer_id"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isSent:     try c.decodeIfPresent(Bool.self,   forKey: .isSent) ?? false,
            documentId: try c.decodeIfPresent(String.self, forKey: .documentId),
            signerId:   try c.decodeIfPresent(String.self, forKey: .signerId)
        )
    }
}
