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
    public let signers: [Signer]

    init(signerCount: Int, completedCount: Int, signers: [Signer] = []) {
        self.signerCount = signerCount
        self.completedCount = completedCount
        self.signers = signers
    }
}

extension AssignmentSummary: @unchecked Sendable {}

extension AssignmentSummary: Decodable {
    enum CodingKeys: String, CodingKey {
        case signerCount    = "signer_count"
        case completedCount = "completed_count"
        case signers
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            signerCount:    try c.decode(Int.self, forKey: .signerCount),
            completedCount: try c.decode(Int.self, forKey: .completedCount),
            signers:        (try? c.decode([Signer].self, forKey: .signers)) ?? []
        )
    }
}

// MARK: - AssignmentItem

/// One field item that a signer must complete in a collect assignment.
@objcMembers
public final class AssignmentItem: NSObject {
    public let id: String
    public let page: DocumentPage?
    public let signer: Signer?
    public let field: FieldDefinition?
    public let displaySettings: String?
    public let value: String?
    public let completed: Bool

    init(id: String, page: DocumentPage? = nil, signer: Signer? = nil,
         field: FieldDefinition? = nil, displaySettings: String? = nil,
         value: String? = nil, completed: Bool = false) {
        self.id = id
        self.page = page
        self.signer = signer
        self.field = field
        self.displaySettings = displaySettings
        self.value = value
        self.completed = completed
    }
}

extension AssignmentItem: @unchecked Sendable {}

extension AssignmentItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, page, signer, field, value, completed
        case displaySettings = "display_settings"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            page: try c.decodeIfPresent(DocumentPage.self, forKey: .page),
            signer: try c.decodeIfPresent(Signer.self, forKey: .signer),
            field: try c.decodeIfPresent(FieldDefinition.self, forKey: .field),
            displaySettings: try decodeFlexibleOptionalString(from: c, forKey: .displaySettings),
            value: try decodeFlexibleOptionalString(from: c, forKey: .value),
            completed: try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        )
    }
}

// MARK: - AssignmentSigningURL

/// Direct signing URL generated for a signer.
@objcMembers
public final class AssignmentSigningURL: NSObject {
    public let signerId: String
    public let url: String

    init(signerId: String, url: String) {
        self.signerId = signerId
        self.url = url
    }
}

extension AssignmentSigningURL: @unchecked Sendable {}

extension AssignmentSigningURL: Decodable {
    enum CodingKeys: String, CodingKey {
        case signerId = "signer_id"
        case url
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            signerId: try c.decode(String.self, forKey: .signerId),
            url: try c.decode(String.self, forKey: .url)
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
    /// Signers configured as copy receivers on this assignment.
    ///
    /// The API responds with full signer objects. When creating an
    /// assignment, pass signer IDs in
    /// ``CreateAssignmentPayload/copyReceivers``.
    public let copyReceivers: [Signer]
    /// Field items associated with this assignment.
    public let items: [AssignmentItem]
    public let summary: AssignmentSummary?
    /// Direct signing URLs generated by the API for each signer.
    public let signingUrls: [AssignmentSigningURL]

    init(id: String, senderEmail: String? = nil, method: AssignmentMethod, methodString: String,
         expiresAt: String? = nil, message: String? = nil, signers: [Signer] = [],
         copyReceivers: [Signer] = [], items: [AssignmentItem] = [],
         summary: AssignmentSummary? = nil, signingUrls: [AssignmentSigningURL] = []) {
        self.id = id; self.senderEmail = senderEmail
        self.method = method; self.methodString = methodString
        self.expiresAt = expiresAt; self.message = message
        self.signers = signers; self.copyReceivers = copyReceivers
        self.items = items
        self.summary = summary
        self.signingUrls = signingUrls
    }
}

extension Assignment: @unchecked Sendable {}

extension Assignment: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, method, message, signers, items, summary
        case senderEmail    = "sender_email"
        case expiresAt      = "expires_at"
        case copyReceivers  = "copy_receivers"
        case signingUrls    = "signing_urls"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let methodString = try c.decode(String.self, forKey: .method)
        self.init(
            id:            try c.decode(String.self,                  forKey: .id),
            senderEmail:   try c.decodeIfPresent(String.self,         forKey: .senderEmail),
            method:        AssignmentMethod(string: methodString),
            methodString:  methodString,
            expiresAt:     try decodeFlexibleOptionalString(from: c, forKey: .expiresAt),
            message:       try c.decodeIfPresent(String.self,         forKey: .message),
            signers:       (try? c.decode([Signer].self, forKey: .signers)) ?? [],
            copyReceivers: (try? c.decode([Signer].self, forKey: .copyReceivers)) ?? [],
            items:         (try? c.decode([AssignmentItem].self, forKey: .items)) ?? [],
            summary:       try c.decodeIfPresent(AssignmentSummary.self, forKey: .summary),
            signingUrls:   (try? c.decode([AssignmentSigningURL].self, forKey: .signingUrls)) ?? []
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

// MARK: - SignAssignmentField

/// A single signed field placement payload sent by a signer.
@objcMembers
public final class SignAssignmentField: NSObject, Encodable {
    public let itemId: String
    public let fieldId: String
    public let pageId: String?
    public let value: String

    @objc public init(itemId: String, fieldId: String, pageId: String? = nil, value: String) {
        self.itemId = itemId; self.fieldId = fieldId
        self.pageId = pageId; self.value = value
    }

    enum CodingKeys: String, CodingKey { case itemId, fieldId, pageId, value }
}

extension SignAssignmentField: @unchecked Sendable {}

// MARK: - WhatsappNotification

/// A single WhatsApp notification record returned by
/// `GET /documents/{id}/assignments/{aid}/whatsapp-notifications`.
@objcMembers
public final class WhatsappNotification: NSObject {
    /// Unix timestamp (seconds) when the WhatsApp message was sent.
    public let sentAt: Int
    /// Rendered header text.
    public let header: String?
    /// Rendered body text.
    public let body: String?
    /// Action buttons rendered in the message (only `text` is exposed).
    public let buttonTexts: [String]
    /// Recipient phone number (E.164).
    public let phoneNumber: String?
    /// ID of the signer that received the notification.
    public let signerId: String?

    init(sentAt: Int, header: String? = nil, body: String? = nil,
         buttonTexts: [String] = [], phoneNumber: String? = nil, signerId: String? = nil) {
        self.sentAt = sentAt; self.header = header; self.body = body
        self.buttonTexts = buttonTexts
        self.phoneNumber = phoneNumber; self.signerId = signerId
    }
}

extension WhatsappNotification: @unchecked Sendable {}

extension WhatsappNotification: Decodable {
    enum CodingKeys: String, CodingKey {
        case sentAt = "sent_at"
        case header, body, buttons
        case phoneNumber = "phone_number"
        case signerId = "signer_id"
    }

    struct Button: Decodable { let text: String? }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let buttons = (try? c.decode([Button].self, forKey: .buttons)) ?? []
        self.init(
            sentAt: try c.decodeIfPresent(Int.self, forKey: .sentAt) ?? 0,
            header: try c.decodeIfPresent(String.self, forKey: .header),
            body: try c.decodeIfPresent(String.self, forKey: .body),
            buttonTexts: buttons.compactMap(\.text),
            phoneNumber: try c.decodeIfPresent(String.self, forKey: .phoneNumber),
            signerId: try c.decodeIfPresent(String.self, forKey: .signerId)
        )
    }
}

// MARK: - DeclineAssignmentPayload

/// Payload for `PUT /documents/{id}/assignments/{aid}/reject`.
@objcMembers
public final class DeclineAssignmentPayload: NSObject, Encodable {
    public let declineReason: String

    @objc public init(declineReason: String) {
        self.declineReason = declineReason
    }

    enum CodingKeys: String, CodingKey { case declineReason = "decline_reason" }
}

extension DeclineAssignmentPayload: @unchecked Sendable {}

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
