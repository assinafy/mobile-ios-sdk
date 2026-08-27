import Foundation

// MARK: - Signer

/// A signer registered in a workspace.
@objcMembers
public final class Signer: NSObject {
    /// Resource discriminator returned by the API.
    public let resource: String?
    public let id: String
    public let fullName: String
    public let email: String?
    public let whatsappPhoneNumber: String?
    public let hasAcceptedTerms: Bool
    public let verificationMethod: String?
    public let notificationMethods: [String]
    /// The signing step (1-based) in an ordered assignment, when present.
    public let step: Int
    /// Whether an assignment notification has been sent, or `nil` when not reported.
    public let notified: NSNumber?
    public let completed: Bool
    public let notificationHistory: [SignerNotificationHistory]

    init(id: String, fullName: String, email: String,
         whatsappPhoneNumber: String? = nil, hasAcceptedTerms: Bool = false) {
        self.resource = nil
        self.id = id; self.fullName = fullName; self.email = email
        self.whatsappPhoneNumber = whatsappPhoneNumber
        self.hasAcceptedTerms = hasAcceptedTerms
        self.verificationMethod = nil; self.notificationMethods = []
        self.step = 0
        self.notified = nil
        self.completed = false; self.notificationHistory = []
    }

    init(
        resource: String? = nil,
        id: String,
        fullName: String,
        email: String?,
        whatsappPhoneNumber: String? = nil,
        hasAcceptedTerms: Bool = false,
        verificationMethod: String? = nil,
        notificationMethods: [String] = [],
        step: Int = 0,
        notified: NSNumber? = nil,
        completed: Bool = false,
        notificationHistory: [SignerNotificationHistory] = []
    ) {
        self.resource = resource
        self.id = id; self.fullName = fullName; self.email = email
        self.whatsappPhoneNumber = whatsappPhoneNumber
        self.hasAcceptedTerms = hasAcceptedTerms
        self.verificationMethod = verificationMethod
        self.notificationMethods = notificationMethods
        self.step = step
        self.notified = notified
        self.completed = completed
        self.notificationHistory = notificationHistory
    }

    public override var description: String {
        "Signer(id: \(id))"
    }
}

extension Signer: @unchecked Sendable {}

extension Signer: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, email, step, notified, completed
        case fullName            = "full_name"
        case whatsappPhoneNumber = "whatsapp_phone_number"
        case hasAcceptedTerms    = "has_accepted_terms"
        case verificationMethod  = "verification_method"
        case notificationMethods = "notification_methods"
        case notificationHistory = "notification_history"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            resource:             try c.decodeIfPresent(String.self,  forKey: .resource),
            id:                   try c.decode(String.self,           forKey: .id),
            fullName:             try c.decode(String.self,           forKey: .fullName),
            email:                try c.decodeIfPresent(String.self,  forKey: .email),
            whatsappPhoneNumber:  try c.decodeIfPresent(String.self,  forKey: .whatsappPhoneNumber),
            hasAcceptedTerms:     try c.decodeIfPresent(Bool.self,    forKey: .hasAcceptedTerms) ?? false,
            verificationMethod:   try c.decodeIfPresent(String.self,  forKey: .verificationMethod),
            notificationMethods:  try c.decodeIfPresent([String].self, forKey: .notificationMethods) ?? [],
            step:                 try c.decodeIfPresent(Int.self,     forKey: .step) ?? 0,
            notified:             try c.decodeIfPresent(Bool.self, forKey: .notified).map { NSNumber(value: $0) },
            completed:            try c.decodeIfPresent(Bool.self,    forKey: .completed) ?? false,
            notificationHistory:  try c.decodeIfPresent([SignerNotificationHistory].self, forKey: .notificationHistory) ?? []
        )
    }
}

// MARK: - SignerNotificationHistory

/// Notification delivery status for a signer inside an assignment response.
@objcMembers
public final class SignerNotificationHistory: NSObject {
    public let event: String
    public let status: String
    public let errorCode: String?
    public let errorMessage: String?
    public let sentAt: String?
    public let failedAt: String?

    init(event: String, status: String, errorCode: String? = nil, errorMessage: String? = nil,
         sentAt: String? = nil, failedAt: String? = nil) {
        self.event = event
        self.status = status
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.sentAt = sentAt
        self.failedAt = failedAt
    }
}

extension SignerNotificationHistory: @unchecked Sendable {}

extension SignerNotificationHistory: Decodable {
    enum CodingKeys: String, CodingKey {
        case event, status
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case sentAt = "sent_at"
        case failedAt = "failed_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            event: try c.decodeIfPresent(String.self, forKey: .event) ?? "",
            status: try c.decodeIfPresent(String.self, forKey: .status) ?? "",
            errorCode: try decodeFlexibleOptionalString(from: c, forKey: .errorCode),
            errorMessage: try c.decodeIfPresent(String.self, forKey: .errorMessage),
            sentAt: try decodeFlexibleOptionalString(from: c, forKey: .sentAt),
            failedAt: try decodeFlexibleOptionalString(from: c, forKey: .failedAt)
        )
    }
}

// MARK: - CreateSignerPayload

/// Payload for creating a new signer in the workspace.
///
/// ``SignerResource/create(_:accountId:)`` is idempotent by email — if a signer with
/// the given address already exists, the SDK returns the existing record.
///
/// ## Example
/// ```swift
/// let payload = CreateSignerPayload(
///     fullName: "John Doe",
///     email: "john@example.com",
///     whatsappPhoneNumber: "+5548999990000"
/// )
/// let signer = try await client.signers.create(payload)
/// ```
@objcMembers
public final class CreateSignerPayload: NSObject, Encodable {
    /// The signer's full display name.
    public let fullName: String
    /// The signer's email address. Required for email-based flows.
    public let email: String?
    /// The signer's WhatsApp-enabled phone number in E.164 format.
    public let whatsappPhoneNumber: String?

    /// Creates a new signer payload.
    ///
    /// - Parameters:
    ///   - fullName: The signer's full display name.
    ///   - email: A valid email address.
    ///   - whatsappPhoneNumber: E.164 phone number for WhatsApp notifications.
    @objc public init(
        fullName: String,
        email: String? = nil,
        whatsappPhoneNumber: String? = nil
    ) {
        self.fullName = fullName
        self.email = email
        self.whatsappPhoneNumber = whatsappPhoneNumber
    }

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case email
        case whatsappPhoneNumber = "whatsapp_phone_number"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fullName, forKey: .fullName)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(whatsappPhoneNumber, forKey: .whatsappPhoneNumber)
    }
}

extension CreateSignerPayload: @unchecked Sendable {}

// MARK: - UpdateSignerPayload

/// Payload for updating an existing signer's details.
///
/// Only provide fields you wish to change; omitted fields are left unchanged.
@objcMembers
public final class UpdateSignerPayload: NSObject, Encodable {
    public let fullName: String?
    public let email: String?
    public let whatsappPhoneNumber: String?
    public private(set) var governmentId: String?

    /// Creates a partial signer update; omitted values remain unchanged.
    @objc public init(
        fullName: String? = nil,
        email: String? = nil,
        whatsappPhoneNumber: String? = nil
    ) {
        self.fullName = fullName
        self.email = email
        self.whatsappPhoneNumber = whatsappPhoneNumber
        self.governmentId = nil
    }

    /// Creates a signer update that can include the documented CPF/CNPJ field.
    @objc(initWithFullName:email:whatsappPhoneNumber:governmentId:)
    public convenience init(
        fullName: String? = nil,
        email: String? = nil,
        whatsappPhoneNumber: String? = nil,
        governmentId: String
    ) {
        self.init(fullName: fullName, email: email, whatsappPhoneNumber: whatsappPhoneNumber)
        self.governmentId = governmentId
    }

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case email
        case whatsappPhoneNumber = "whatsapp_phone_number"
        case governmentId = "government_id"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(fullName, forKey: .fullName)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(whatsappPhoneNumber, forKey: .whatsappPhoneNumber)
        try c.encodeIfPresent(governmentId, forKey: .governmentId)
    }
}

extension UpdateSignerPayload: @unchecked Sendable {}

// MARK: - SignerSelfInfo

/// Signer information returned by the self-service endpoint.
///
/// Includes additional fields beyond the base ``Signer`` model.
@objcMembers
public final class SignerSelfInfo: NSObject {
    /// Resource discriminator returned by the API.
    public let resource: String?
    public let id: String
    public let fullName: String
    public let email: String?
    public let whatsappPhoneNumber: String?
    public let hasAcceptedTerms: Bool
    public let hasSignature: Bool
    public let hasInitial: Bool
    public let isSignatureReusable: Bool

    init(resource: String? = nil, id: String, fullName: String, email: String?, whatsappPhoneNumber: String? = nil,
         hasAcceptedTerms: Bool, hasSignature: Bool, hasInitial: Bool,
         isSignatureReusable: Bool = false) {
        self.resource = resource
        self.id = id; self.fullName = fullName; self.email = email
        self.whatsappPhoneNumber = whatsappPhoneNumber
        self.hasAcceptedTerms = hasAcceptedTerms
        self.hasSignature = hasSignature; self.hasInitial = hasInitial
        self.isSignatureReusable = isSignatureReusable
    }
}

extension SignerSelfInfo: @unchecked Sendable {}

extension SignerSelfInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, email
        case fullName            = "full_name"
        case whatsappPhoneNumber = "whatsapp_phone_number"
        case hasAcceptedTerms   = "has_accepted_terms"
        case hasSignature       = "has_signature"
        case hasInitial         = "has_initial"
        case isSignatureReusable = "is_signature_reusable"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            resource:             try c.decodeIfPresent(String.self, forKey: .resource),
            id:                   try c.decode(String.self, forKey: .id),
            fullName:             try c.decode(String.self, forKey: .fullName),
            email:                try c.decodeIfPresent(String.self, forKey: .email),
            whatsappPhoneNumber:  try c.decodeIfPresent(String.self, forKey: .whatsappPhoneNumber),
            hasAcceptedTerms:    try c.decodeIfPresent(Bool.self, forKey: .hasAcceptedTerms) ?? false,
            hasSignature:        try c.decodeIfPresent(Bool.self, forKey: .hasSignature) ?? false,
            hasInitial:          try c.decodeIfPresent(Bool.self, forKey: .hasInitial) ?? false,
            isSignatureReusable: try c.decodeIfPresent(Bool.self, forKey: .isSignatureReusable) ?? false
        )
    }
}

// MARK: - AcceptTermsResponse

/// Response returned after a signer accepts terms of use.
@objcMembers
public final class AcceptTermsResponse: NSObject {
    public let fullName: String
    public let email: String
    public let hasAcceptedTerms: Bool

    init(fullName: String, email: String, hasAcceptedTerms: Bool) {
        self.fullName = fullName; self.email = email; self.hasAcceptedTerms = hasAcceptedTerms
    }
}

extension AcceptTermsResponse: @unchecked Sendable {}

extension AcceptTermsResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case fullName         = "full_name"
        case email
        case hasAcceptedTerms = "has_accepted_terms"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            fullName:         try c.decode(String.self, forKey: .fullName),
            email:            try c.decode(String.self, forKey: .email),
            hasAcceptedTerms: try c.decode(Bool.self, forKey: .hasAcceptedTerms)
        )
    }
}

// MARK: - VerifyEmailPayload

/// Payload for email verification.
@objcMembers
public final class VerifyEmailPayload: NSObject, Encodable {
    public let verificationCode: String
    public let signerAccessCode: String

    /// Creates an email-verification request.
    /// - Parameters:
    ///   - verificationCode: One-time code received by email.
    ///   - signerAccessCode: Signer access code sent as a query parameter.
    @objc public init(verificationCode: String, signerAccessCode: String) {
        self.verificationCode = verificationCode
        self.signerAccessCode = signerAccessCode
    }

    enum CodingKeys: String, CodingKey {
        case verificationCode  = "verification-code"
        case signerAccessCode  = "signer-access-code"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(verificationCode, forKey: .verificationCode)
    }
}

extension VerifyEmailPayload: @unchecked Sendable {}

// MARK: - ConfirmSignerDataPayload

/// Payload for `PUT /documents/{id}/signers/confirm-data`.
///
/// The documented fields are `full_name`, `email`, and `government_id`; the SDK
/// also forwards `whatsapp_phone_number` and `has_accepted_terms`, which the
/// live signing flow accepts. Provide only the fields you need to confirm.
@objcMembers
public final class ConfirmSignerDataPayload: NSObject, Encodable {
    public let fullName: String?
    public let email: String?
    /// The signer's government-issued identifier (e.g. CPF), per the API docs.
    public let governmentId: String?
    public let whatsappPhoneNumber: String?
    public let hasAcceptedTerms: Bool

    /// Creates signer data to confirm before virtual signing.
    @objc public init(
        fullName: String? = nil,
        email: String? = nil,
        governmentId: String? = nil,
        whatsappPhoneNumber: String? = nil,
        hasAcceptedTerms: Bool = false
    ) {
        self.fullName = fullName
        self.email = email
        self.governmentId = governmentId
        self.whatsappPhoneNumber = whatsappPhoneNumber
        self.hasAcceptedTerms = hasAcceptedTerms
    }

    enum CodingKeys: String, CodingKey {
        case fullName            = "full_name"
        case email
        case governmentId        = "government_id"
        case whatsappPhoneNumber = "whatsapp_phone_number"
        case hasAcceptedTerms    = "has_accepted_terms"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(fullName, forKey: .fullName)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(governmentId, forKey: .governmentId)
        try c.encodeIfPresent(whatsappPhoneNumber, forKey: .whatsappPhoneNumber)
        if hasAcceptedTerms {
            try c.encode(true, forKey: .hasAcceptedTerms)
        }
    }
}

extension ConfirmSignerDataPayload: @unchecked Sendable {}

// MARK: - SignatureType

/// The type of signature image.
@objc public enum SignatureType: Int, Sendable {
    case signature = 0
    case initial = 1

    var stringValue: String {
        switch self {
        case .signature: return "signature"
        case .initial:   return "initial"
        }
    }
}

// MARK: - Signer-facing document filtering

/// Parameters for ``SignerResource/listSignerDocuments(signerId:signerAccessCode:params:)``.
@objcMembers
public final class SignerDocumentListParams: NSObject {
    /// Legacy server extension retained for compatibility.
    public var status: String?
    /// Legacy server extension retained for compatibility.
    public var method: String?
    /// Legacy server extension retained for compatibility.
    public var search: String?
    /// Legacy server extension retained for compatibility.
    public var sort: String?
    public var page: Int
    public var perPage: Int

    /// Creates legacy signer-document filters retained for compatibility.
    @objc public init(
        status: String? = nil,
        method: String? = nil,
        search: String? = nil,
        sort: String? = nil
    ) {
        self.status = status
        self.method = method
        self.search = search
        self.sort = sort
        self.page = 0
        self.perPage = 0
    }

    /// Creates the documented pagination parameters.
    @objc(initWithPage:perPage:)
    public convenience init(page: Int, perPage: Int) {
        self.init()
        self.page = page
        self.perPage = perPage
    }

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if page > 0 { items.append(.init(name: "page", value: "\(page)")) }
        if perPage > 0 { items.append(.init(name: "per-page", value: "\(perPage)")) }
        if let status, !status.isEmpty { items.append(.init(name: "status", value: status)) }
        if let method, !method.isEmpty { items.append(.init(name: "method", value: method)) }
        if let search, !search.isEmpty { items.append(.init(name: "search", value: search)) }
        if let sort, !sort.isEmpty { items.append(.init(name: "sort", value: sort)) }
        return items
    }
}

extension SignerDocumentListParams: @unchecked Sendable {}

// MARK: - SignMultipleDocumentsPayload

/// Payload for `PUT /signers/documents/sign-multiple`.
@objcMembers
public final class SignMultipleDocumentsPayload: NSObject, Encodable {
    public let documentIds: [String]

    /// Creates a batch-signing payload for the supplied document IDs.
    @objc public init(documentIds: [String]) {
        self.documentIds = documentIds
    }

    enum CodingKeys: String, CodingKey { case documentIds = "document_ids" }
}

extension SignMultipleDocumentsPayload: @unchecked Sendable {}

// MARK: - DeclineMultipleDocumentsPayload

/// Payload for `PUT /signers/documents/decline-multiple`.
@objcMembers
public final class DeclineMultipleDocumentsPayload: NSObject, Encodable {
    public let documentIds: [String]
    public let declineReason: String

    /// Creates a batch-decline payload and shared rejection reason.
    @objc public init(documentIds: [String], declineReason: String) {
        self.documentIds = documentIds
        self.declineReason = declineReason
    }

    enum CodingKeys: String, CodingKey {
        case documentIds = "document_ids"
        case declineReason = "decline_reason"
    }
}

extension DeclineMultipleDocumentsPayload: @unchecked Sendable {}
