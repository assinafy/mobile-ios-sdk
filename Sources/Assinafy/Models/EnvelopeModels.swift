import Foundation

/// A signer’s progress on one document of an envelope.
@objcMembers
public final class EnvelopeSigner: NSObject, Decodable {
    /// Signer ID.
    public let id: String
    /// Signer name.
    public let fullName: String
    /// Email contact, when present.
    public let email: String?
    /// WhatsApp contact, when present.
    public let whatsappPhoneNumber: String?
    /// Whether this document was signed.
    public let completed: Bool
    /// ISO-8601 signing time.
    public let signedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case whatsappPhoneNumber = "whatsapp_phone_number"
        case completed
        case signedAt = "signed_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fullName = try c.decode(String.self, forKey: .fullName)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        whatsappPhoneNumber = try c.decodeIfPresent(String.self, forKey: .whatsappPhoneNumber)
        completed = try c.decode(Bool.self, forKey: .completed)
        signedAt = try c.decodeIfPresent(String.self, forKey: .signedAt)
    }
}

extension EnvelopeSigner: @unchecked Sendable {}

/// A document in an envelope, including its independent status and artifacts.
@objcMembers
public final class EnvelopeDocument: NSObject, Decodable {
    /// Document ID.
    public let id: String
    /// One-based order.
    public let position: Int
    /// Document name.
    public let name: String
    /// Document lifecycle code.
    public let status: String
    /// Artifact URLs; list responses may include only thumbnail.
    public let artifacts: [String: String]
    /// Signers of this document.
    public let signers: [EnvelopeSigner]

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case name
        case status
        case artifacts
        case signers
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        position = try c.decode(Int.self, forKey: .position)
        name = try c.decode(String.self, forKey: .name)
        status = try c.decode(String.self, forKey: .status)
        artifacts = try c.decode([String: String].self, forKey: .artifacts)
        signers = try c.decode([EnvelopeSigner].self, forKey: .signers)
    }
}

extension EnvelopeDocument: @unchecked Sendable {}

/// Documents sent together. Each retains its own assignment and certification.
@objcMembers
public final class DocumentEnvelope: NSObject, Decodable {
    /// Envelope ID.
    public let id: String
    /// Invitation title.
    public let name: String
    /// Invitation message.
    public let message: String?
    /// Documents in display order.
    public let documents: [EnvelopeDocument]
    /// Counts by document status; nil for an empty envelope.
    public let counts: [String: Int]?
    /// Invitation or embed entry for each signer.
    public let signingUrls: [AssignmentSigningURL]
    /// ISO-8601 creation time.
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case message
        case documents
        case counts
        case signingUrls = "signing_urls"
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        documents = try c.decode([EnvelopeDocument].self, forKey: .documents)
        counts = try c.decodeIfPresent([String: Int].self, forKey: .counts)
        signingUrls = try c.decode([AssignmentSigningURL].self, forKey: .signingUrls)
        createdAt = try c.decode(String.self, forKey: .createdAt)
    }
}

extension DocumentEnvelope: @unchecked Sendable {}

/// Result of cancelling one envelope document.
@objcMembers
public final class EnvelopeCancellation: NSObject, Decodable {
    /// Document ID.
    public let id: String
    /// Status after cancellation.
    public let status: String
    /// True only when this call cancelled the document.
    public let cancelled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case cancelled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decode(String.self, forKey: .status)
        cancelled = try c.decode(Bool.self, forKey: .cancelled)
    }
}

extension EnvelopeCancellation: @unchecked Sendable {}

/// Envelope identity included by the envelope expansion.
@objcMembers
public final class EnvelopeSummary: NSObject, Decodable {
    /// Envelope ID.
    public let id: String
    /// Envelope title.
    public let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
    }
}

extension EnvelopeSummary: @unchecked Sendable {}

/// A prepared document and its signers for envelope creation or addition.
public struct EnvelopeDocumentPayload: Sendable, Encodable {
    public var id: String
    public var signerIds: [String]
    public var method: AssignmentMethod = .virtual
    public var entries: [AssignmentEntry]?
    public var expiresAt: String?
    public var copyReceiverIds: [String]?
    /// Used when adding a document; creation uses the envelope's ceiling.
    public var maxTotalCredits: Decimal?

    public init(id: String, signerIds: [String]) {
        self.id = id
        self.signerIds = signerIds
    }

    public init(jsonData: Data) throws {
        try self.init(body: JSONDecoder.assinafy.decode(EnvelopeDocumentBody.self, from: jsonData))
    }

    init(body: EnvelopeDocumentBody) throws {
        guard body.method == nil || body.method == "virtual" || body.method == "collect" else {
            throw ValidationError("Envelope document method must be virtual or collect")
        }
        self.init(id: body.id, signerIds: body.signerIds)
        method = AssignmentMethod(string: body.method ?? "virtual")
        entries = body.entries?.map { entry in
            AssignmentEntry(pageId: entry.pageId, fields: entry.fields.map { field in
                if let settings = field.displaySettings {
                    return AssignmentField(signerId: field.signerId, fieldId: field.fieldId, displaySettings: settings)
                }
                return AssignmentField(signerId: field.signerId, fieldId: field.fieldId)
            })
        }
        expiresAt = body.expiresAt
        copyReceiverIds = body.copyReceiverIds
        maxTotalCredits = body.maxTotalCredits
    }

    public func encode(to encoder: Encoder) throws {
        _ = try AssinafyClientConfiguration.validateIdentifier(id, name: "Document ID")
        guard !signerIds.isEmpty, Set(signerIds).count == signerIds.count else {
            throw ValidationError("Each envelope document needs distinct signer IDs")
        }
        try validateCreditCeiling(maxTotalCredits)
        let body = try buildAssignmentBody(CreateAssignmentPayload(
            method: method, signers: signerIds.map { .id($0) }, entries: entries
        ))
        try EnvelopeDocumentBody(id: id, signerIds: signerIds, method: method.stringValue,
                                 entries: body.entries, expiresAt: expiresAt,
                                 copyReceiverIds: copyReceiverIds, maxTotalCredits: maxTotalCredits).encode(to: encoder)
    }
}

struct EnvelopeDocumentBody: Codable {
    let id: String
    let signerIds: [String]
    let method: String?
    let entries: [AssignmentEntryBody]?
    let expiresAt: String?
    let copyReceiverIds: [String]?
    let maxTotalCredits: Decimal?
    enum CodingKeys: String, CodingKey {
        case id, method, entries
        case signerIds = "signer_ids", expiresAt = "expires_at"
        case copyReceiverIds = "copy_receiver_ids", maxTotalCredits = "max_total_credits"
    }
}

/// Creates an envelope of 1–20 prepared documents for 1–20 existing signers.
/// Signers act in parallel; every signer must appear on at least one document.
public struct CreateEnvelopePayload: Sendable, Encodable {
    public var name: String
    public var message: String?
    public var signers: [SignerReference]
    public var embeddedSignerIds: [String] = []
    public var documents: [EnvelopeDocumentPayload]
    public var maxTotalCredits: Decimal?

    public init(name: String, signers: [SignerReference], documents: [EnvelopeDocumentPayload]) {
        self.name = name
        self.signers = signers
        self.documents = documents
    }

    public init(jsonData: Data) throws {
        struct Body: Decodable {
            let name: String
            let message: String?
            let signers: [AssignmentSignerBody]
            let documents: [EnvelopeDocumentBody]
            let max_total_credits: Decimal?
        }
        let body = try JSONDecoder.assinafy.decode(Body.self, from: jsonData)
        self.init(name: body.name, signers: body.signers.map {
            .descriptor(id: $0.id, verificationMethod: $0.verificationMethod,
                        notificationMethods: $0.notificationMethods, step: $0.step)
        }, documents: try body.documents.map { try EnvelopeDocumentPayload(body: $0) })
        message = body.message
        embeddedSignerIds = body.signers.filter { $0.embedded == true }.compactMap(\.id)
        maxTotalCredits = body.max_total_credits
    }

    public func encode(to encoder: Encoder) throws {
        guard !name.isBlank, name.unicodeScalars.count <= 255, !name.contains("<"),
              (1...20).contains(signers.count), (1...20).contains(documents.count) else {
            throw ValidationError("Envelope needs a name of 1–255 characters without <, and 1–20 signers and documents")
        }
        var assignment = CreateAssignmentPayload(signers: signers)
        assignment.embeddedSignerIds = embeddedSignerIds
        assignment.maxTotalCredits = maxTotalCredits
        let signerBodies = try buildAssignmentBody(assignment).signers
        let ids = signerBodies.compactMap(\.id)
        guard Set(ids).count == ids.count, signerBodies.allSatisfy({ $0.step == nil }),
              Set(documents.map(\.id)).count == documents.count,
              Set(documents.flatMap(\.signerIds)) == Set(ids) else {
            throw ValidationError("Envelope signers and documents must be distinct, without steps; every signer must be used")
        }
        for signer in signerBodies where signer.verificationMethod == "DigitalCertificate" {
            guard documents.filter({ $0.signerIds.contains(signer.id ?? "") }).allSatisfy({
                $0.method == .virtual && $0.signerIds.count == 1
            }) else { throw ValidationError("Certificate signers need virtual documents with no other signer") }
        }
        struct Body: Encodable {
            let name: String
            let message: String?
            let signers: [AssignmentSignerBody]
            let documents: [EnvelopeDocumentPayload]
            let max_total_credits: Decimal?
        }
        try Body(name: name, message: message, signers: signerBodies, documents: documents,
                 max_total_credits: maxTotalCredits).encode(to: encoder)
    }
}

/// Partial envelope edit. Set clearMessage to remove the message; nil otherwise omits it.
@objcMembers
public final class UpdateEnvelopePayload: NSObject, Encodable {
    public var name: String?
    public var message: String?
    public var clearMessage = false
    public var documentIds: [String]?

    public override init() { super.init() }

    enum CodingKeys: String, CodingKey { case name, message, documentIds = "document_ids" }

    public func encode(to encoder: Encoder) throws {
        guard !clearMessage || message == nil else { throw ValidationError("Cannot set and clear message together") }
        if let name, name.isBlank || name.unicodeScalars.count > 255 || name.contains("<") {
            throw ValidationError("Envelope name must contain 1–255 characters without <")
        }
        if let documentIds, documentIds.isEmpty || Set(documentIds).count != documentIds.count {
            throw ValidationError("Document order must contain distinct IDs")
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        if clearMessage { try c.encodeNil(forKey: .message) }
        else { try c.encodeIfPresent(message, forKey: .message) }
        try c.encodeIfPresent(documentIds, forKey: .documentIds)
    }
}

extension UpdateEnvelopePayload: @unchecked Sendable {}
