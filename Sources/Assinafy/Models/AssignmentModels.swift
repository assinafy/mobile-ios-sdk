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

    /// Creates a signing method from its API string, defaulting unknown values to ``virtual``.
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
            signers:        try c.decodeIfPresent([Signer].self, forKey: .signers) ?? []
        )
    }
}

// MARK: - DisplaySettings

/// Placement and presentation settings for a collect-assignment field.
///
/// Geometry is measured in Assinafy's 150-DPI page-image pixels from the
/// upper-left corner. Width, height, and font size must be greater than zero.
@objcMembers
public final class DisplaySettings: NSObject, Codable {
    /// Horizontal distance from the page's left edge.
    public let left: Double
    /// Vertical distance from the page's top edge.
    public let top: Double
    /// Placement rectangle width.
    public let width: Double
    /// Placement rectangle height.
    public let height: Double
    /// Optional CSS font-family metadata.
    public let fontFamily: String?
    /// Font size in page-image pixels.
    public let fontSize: Double
    /// Optional CSS-compatible background color.
    public let backgroundColor: String?

    /// Creates field placement geometry and presentation metadata.
    /// - Parameters:
    ///   - left: Horizontal offset in page-image pixels.
    ///   - top: Vertical offset in page-image pixels.
    ///   - width: Rectangle width in page-image pixels.
    ///   - height: Rectangle height in page-image pixels.
    ///   - fontFamily: Optional CSS font family.
    ///   - fontSize: Font size in page-image pixels.
    ///   - backgroundColor: Optional CSS-compatible background color.
    public init(
        left: Double,
        top: Double,
        width: Double,
        height: Double,
        fontFamily: String? = nil,
        fontSize: Double,
        backgroundColor: String? = nil
    ) {
        self.left = left
        self.top = top
        self.width = width
        self.height = height
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.backgroundColor = backgroundColor
    }
}

extension DisplaySettings: @unchecked Sendable {}

// MARK: - AssignmentItem

/// One field item that a signer must complete in a collect assignment.
@objcMembers
public final class AssignmentItem: NSObject {
    public let id: String
    public let page: DocumentPage?
    public let signer: Signer?
    public let field: FieldDefinition?
    /// Typed placement settings returned for collect-assignment items.
    public let displaySettingsObject: DisplaySettings?
    private let legacyDisplaySettings: String?
    /// JSON compatibility view of ``displaySettingsObject``.
    @available(*, deprecated, renamed: "displaySettingsObject")
    public var displaySettings: String? { legacyDisplaySettings }
    /// Lossless JSON value captured for this item.
    @nonobjc public let valueJSON: JSONValue?
    /// String compatibility view of ``valueJSON``.
    public let value: String?
    public let completed: Bool

    init(id: String, page: DocumentPage? = nil, signer: Signer? = nil,
         field: FieldDefinition? = nil, displaySettingsObject: DisplaySettings? = nil,
         displaySettings: String? = nil,
         valueJSON: JSONValue? = nil, value: String? = nil, completed: Bool = false) {
        self.id = id
        self.page = page
        self.signer = signer
        self.field = field
        self.displaySettingsObject = displaySettingsObject
        self.legacyDisplaySettings = displaySettings
        self.valueJSON = valueJSON
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
        let displaySettingsObject = try? c.decode(DisplaySettings.self, forKey: .displaySettings)
        let valueJSON = try decodeJSONValue(from: c, forKey: .value)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            page: try c.decodeIfPresent(DocumentPage.self, forKey: .page),
            signer: try c.decodeIfPresent(Signer.self, forKey: .signer),
            field: try c.decodeIfPresent(FieldDefinition.self, forKey: .field),
            displaySettingsObject: displaySettingsObject,
            displaySettings: try decodeFlexibleOptionalString(from: c, forKey: .displaySettings),
            valueJSON: valueJSON,
            value: valueJSON?.stringValue,
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
    /// Resource discriminator returned by the API.
    public let resource: String?
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

    init(resource: String? = nil, id: String, senderEmail: String? = nil,
         method: AssignmentMethod, methodString: String,
         expiresAt: String? = nil, message: String? = nil, signers: [Signer] = [],
         copyReceivers: [Signer] = [], items: [AssignmentItem] = [],
         summary: AssignmentSummary? = nil, signingUrls: [AssignmentSigningURL] = []) {
        self.resource = resource
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
        case resource, id, method, message, signers, items, summary
        case senderEmail    = "sender_email"
        case expiresAt      = "expires_at"
        case expiration
        case copyReceivers  = "copy_receivers"
        case signingUrls    = "signing_urls"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // The collect-assignment create response documents `"method": null`,
        // so decode defensively and default to the documented `virtual` value.
        let methodString = (try c.decodeIfPresent(String.self, forKey: .method)) ?? "virtual"
        // The live API returns `expires_at`; the published docs examples use
        // `expiration`. Accept either so the value is never silently dropped.
        let expiresAt = try decodeFlexibleOptionalString(from: c, forKey: .expiresAt)
            ?? decodeFlexibleOptionalString(from: c, forKey: .expiration)
        self.init(
            resource:      try c.decodeIfPresent(String.self,         forKey: .resource),
            id:            try c.decode(String.self,                  forKey: .id),
            senderEmail:   try c.decodeIfPresent(String.self,         forKey: .senderEmail),
            method:        AssignmentMethod(string: methodString),
            methodString:  methodString,
            expiresAt:     expiresAt,
            message:       try c.decodeIfPresent(String.self,         forKey: .message),
            signers:       try c.decodeIfPresent([Signer].self, forKey: .signers) ?? [],
            copyReceivers: try c.decodeIfPresent([Signer].self, forKey: .copyReceivers) ?? [],
            items:         try c.decodeIfPresent([AssignmentItem].self, forKey: .items) ?? [],
            summary:       try c.decodeIfPresent(AssignmentSummary.self, forKey: .summary),
            signingUrls:   try c.decodeIfPresent([AssignmentSigningURL].self, forKey: .signingUrls) ?? []
        )
    }
}

// MARK: - SignerReference

/// A reference to a signer within an assignment payload.
///
/// Use ``id(_:)`` for a simple signer ID reference, or
/// ``descriptor(id:verificationMethod:notificationMethods:step:)``
/// when you need to specify delivery channels or build cost-estimation payloads.
public enum SignerReference: Sendable {
    /// A signer identified solely by their ID.
    case id(String)
    /// A signer identified by ID and/or method descriptors for cost estimation.
    ///
    /// - Parameter step: The 1-based signing order for ordered (sequential)
    ///   assignments. Leave `nil` for parallel signing.
    case descriptor(
        id: String? = nil,
        verificationMethod: String? = nil,
        notificationMethods: [String]? = nil,
        step: Int? = nil
    )
}

// MARK: - AssignmentField

/// A field placement used by collect assignments.
public struct AssignmentField: Sendable {
    public var signerId: String
    public var fieldId: String
    /// Typed placement settings encoded as the API's `display_settings` object.
    public var displaySettingsObject: DisplaySettings?
    private var legacyDisplaySettings: String?
    /// Legacy JSON representation of `display_settings`.
    @available(*, deprecated, renamed: "displaySettingsObject")
    public var displaySettings: String? {
        get { legacyDisplaySettings }
        set { legacyDisplaySettings = newValue }
    }

    var legacyDisplaySettingsValue: String? { legacyDisplaySettings }

    /// Creates a field placement without display settings.
    public init(signerId: String, fieldId: String) {
        self.signerId = signerId
        self.fieldId = fieldId
        self.displaySettingsObject = nil
        self.legacyDisplaySettings = nil
    }

    /// Creates a field placement with typed display settings.
    public init(signerId: String, fieldId: String, displaySettings: DisplaySettings) {
        self.signerId = signerId
        self.fieldId = fieldId
        self.displaySettingsObject = displaySettings
        self.legacyDisplaySettings = nil
    }

    /// Creates a field placement from a legacy JSON settings string.
    @available(*, deprecated, message: "Pass a DisplaySettings value instead of a JSON string.")
    public init(signerId: String, fieldId: String, displaySettings: String? = nil) {
        self.signerId = signerId
        self.fieldId = fieldId
        self.displaySettingsObject = nil
        self.legacyDisplaySettings = displaySettings
    }
}

// MARK: - AssignmentEntry

/// A page entry containing fields for collect assignments.
public struct AssignmentEntry: Sendable {
    public var pageId: String
    public var fields: [AssignmentField]

    /// Creates a collect-assignment entry for one document page.
    /// - Parameters:
    ///   - pageId: Target document page ID.
    ///   - fields: Field placements on the page.
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

    /// Creates an assignment request payload.
    /// - Parameters:
    ///   - method: Virtual or collect signing method.
    ///   - signers: Signers participating in the assignment.
    ///   - entries: Page field placements required for collect assignments.
    ///   - message: Optional invitation message.
    ///   - expiresAt: Optional ISO-8601 expiration time.
    ///   - copyReceivers: Signer IDs that receive a completed copy only.
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
    let displaySettings: DisplaySettings?

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
    let step: Int?

    enum CodingKeys: String, CodingKey {
        case id, step
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

struct AssignmentEstimateSignerBody: Encodable {
    let verificationMethod: String?
    let notificationMethods: [String]?

    enum CodingKeys: String, CodingKey {
        case verificationMethod = "verification_method"
        case notificationMethods = "notification_methods"
    }
}

struct AssignmentEstimateBody: Encodable {
    let method: String
    let signers: [AssignmentEstimateSignerBody]?
    let entries: [AssignmentEntryBody]?
}

func buildAssignmentBody(_ payload: CreateAssignmentPayload) throws -> AssignmentPayloadBody {
    guard !payload.signers.isEmpty else {
        throw ValidationError("At least one signer is required")
    }
    let signerBodies = try payload.signers.map { ref in
        try buildSignerBody(ref)
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

func buildAssignmentEstimateBody(_ payload: CreateAssignmentPayload) throws -> AssignmentEstimateBody {
    if payload.method == .virtual, payload.signers.isEmpty {
        throw ValidationError("Virtual assignment estimates require at least one signer")
    }
    let signers = payload.signers.map { reference -> AssignmentEstimateSignerBody in
        switch reference {
        case .id:
            return AssignmentEstimateSignerBody(verificationMethod: nil, notificationMethods: nil)
        case .descriptor(_, let verificationMethod, let notificationMethods, _):
            return AssignmentEstimateSignerBody(
                verificationMethod: verificationMethod,
                notificationMethods: notificationMethods
            )
        }
    }
    let entries = try payload.entries?.map(buildEntryBody)
    if payload.method == .collect, entries?.isEmpty != false {
        throw ValidationError("Collect assignment estimates require at least one entry")
    }
    return AssignmentEstimateBody(
        method: payload.method.stringValue,
        signers: signers.isEmpty ? nil : signers,
        entries: entries
    )
}

private func buildSignerBody(_ ref: SignerReference) throws -> AssignmentSignerBody {
    switch ref {
    case .id(let id):
        guard !id.isEmpty else { throw ValidationError("Signer ID cannot be empty") }
        return AssignmentSignerBody(id: id, verificationMethod: nil, notificationMethods: nil, step: nil)
    case .descriptor(let id, let vm, let nm, let step):
        let hasId = id?.isEmpty == false
        guard hasId else { throw ValidationError("Signer ID is required when creating an assignment") }
        return AssignmentSignerBody(id: hasId ? id : nil, verificationMethod: vm, notificationMethods: nm, step: step)
    }
}

private func buildEntryBody(_ entry: AssignmentEntry) throws -> AssignmentEntryBody {
    guard !entry.pageId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw ValidationError("Entry page ID cannot be empty")
    }
    guard !entry.fields.isEmpty else { throw ValidationError("Entry must contain at least one field") }
    let fields = try entry.fields.map { field in
        guard !field.signerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Field signer ID cannot be empty")
        }
        guard !field.fieldId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Field ID cannot be empty")
        }
        let settings: DisplaySettings?
        if let typed = field.displaySettingsObject {
            settings = typed
        } else if let legacy = field.legacyDisplaySettingsValue {
            guard let data = legacy.data(using: .utf8),
                  let decoded = try? JSONDecoder.assinafy.decode(DisplaySettings.self, from: data) else {
                throw ValidationError("Field display settings must be a valid DisplaySettings JSON object")
            }
            settings = decoded
        } else {
            settings = nil
        }
        if let settings {
            guard settings.left.isFinite, settings.left >= 0,
                  settings.top.isFinite, settings.top >= 0,
                  settings.width.isFinite, settings.width > 0,
                  settings.height.isFinite, settings.height > 0,
                  settings.fontSize.isFinite, settings.fontSize > 0 else {
                throw ValidationError("Field display settings contain invalid geometry")
            }
        }
        return AssignmentFieldBody(signerId: field.signerId, fieldId: field.fieldId, displaySettings: settings)
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

    /// Creates a signed value for one assignment item.
    /// - Parameters:
    ///   - itemId: Assignment item ID.
    ///   - fieldId: Associated field definition ID.
    ///   - pageId: Document page ID; required by the signing endpoint.
    ///   - value: String value to submit.
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
        let buttons = try c.decodeIfPresent([Button].self, forKey: .buttons) ?? []
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

    /// Creates a rejection payload with the signer's reason.
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
