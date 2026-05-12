import Foundation

// MARK: - DocumentStatus enum

/// The lifecycle state of a document.
///
/// Used from Objective-C as `ASFDocumentStatus` (Int-based).
/// Use ``stringValue`` to obtain the raw API string for display or logging.
@objc public enum DocumentStatus: Int {
    case unknown          = -1
    case uploading        =  0
    case uploaded         =  1
    case metadataProcessing = 2
    case metadataReady    =  3
    case pendingSignature =  4
    case expired          =  5
    case certificating    =  6
    case certificated     =  7
    case rejectedBySigner =  8
    case rejectedByUser   =  9
    case failed           = 10
}

public extension DocumentStatus {
    /// The raw API string for this status.
    var stringValue: String {
        switch self {
        case .uploading:         return "uploading"
        case .uploaded:          return "uploaded"
        case .metadataProcessing:return "metadata_processing"
        case .metadataReady:     return "metadata_ready"
        case .pendingSignature:  return "pending_signature"
        case .expired:           return "expired"
        case .certificating:     return "certificating"
        case .certificated:      return "certificated"
        case .rejectedBySigner:  return "rejected_by_signer"
        case .rejectedByUser:    return "rejected_by_user"
        case .failed:            return "failed"
        case .unknown:           return "unknown"
        }
    }

    init(string: String) {
        switch string {
        case "uploading":           self = .uploading
        case "uploaded":            self = .uploaded
        case "metadata_processing": self = .metadataProcessing
        case "metadata_ready":      self = .metadataReady
        case "pending_signature":   self = .pendingSignature
        case "expired":            self = .expired
        case "certificating":      self = .certificating
        case "certificated":       self = .certificated
        case "rejected_by_signer": self = .rejectedBySigner
        case "rejected_by_user":   self = .rejectedByUser
        case "failed":             self = .failed
        default:                   self = .unknown
        }
    }
}

// MARK: - DocumentArtifactName

/// The name of a downloadable document artifact.
@objc public enum DocumentArtifactName: Int {
    /// The original unmodified PDF.
    case original = 0
    /// The fully signed and certificated PDF.
    case certificated = 1
    /// The certificate appendix page.
    case certificatePage = 2
    /// A bundle ZIP containing all artifacts.
    case bundle = 3
}

public extension DocumentArtifactName {
    var pathValue: String {
        switch self {
        case .original:        return "original"
        case .certificated:    return "certificated"
        case .certificatePage: return "certificate-page"
        case .bundle:          return "bundle"
        }
    }
}

// MARK: - DocumentArtifacts

/// URLs for each downloadable artifact associated with a document.
///
/// `thumbnail` appears once metadata processing completes; the certificated
/// PDF, certificate page, and bundle ZIP appear after the document has been
/// fully signed and certificated.
@objcMembers
public final class DocumentArtifacts: NSObject {
    public let original: String
    public let thumbnail: String?
    public let certificated: String?
    public let certificatePage: String?
    public let bundle: String?

    init(original: String, thumbnail: String? = nil, certificated: String? = nil,
         certificatePage: String? = nil, bundle: String? = nil) {
        self.original = original
        self.thumbnail = thumbnail
        self.certificated = certificated
        self.certificatePage = certificatePage
        self.bundle = bundle
    }
}

extension DocumentArtifacts: @unchecked Sendable {}

extension DocumentArtifacts: Decodable {
    enum CodingKeys: String, CodingKey {
        case original, thumbnail, certificated, bundle
        case certificatePage = "certificate-page"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            original:        try c.decode(String.self,         forKey: .original),
            thumbnail:       try c.decodeIfPresent(String.self, forKey: .thumbnail),
            certificated:    try c.decodeIfPresent(String.self, forKey: .certificated),
            certificatePage: try c.decodeIfPresent(String.self, forKey: .certificatePage),
            bundle:          try c.decodeIfPresent(String.self, forKey: .bundle)
        )
    }
}

// MARK: - DocumentPage

/// Metadata for a single page within a document.
@objcMembers
public final class DocumentPage: NSObject {
    public let id: String
    public let number: Int
    public let height: Int
    public let width: Int
    public let downloadUrl: String

    init(id: String, number: Int, height: Int, width: Int, downloadUrl: String) {
        self.id = id
        self.number = number
        self.height = height
        self.width = width
        self.downloadUrl = downloadUrl
    }
}

extension DocumentPage: @unchecked Sendable {}

extension DocumentPage: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, number, height, width
        case downloadUrl = "download_url"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:          try c.decode(String.self, forKey: .id),
            number:      try c.decode(Int.self,    forKey: .number),
            height:      try c.decode(Int.self,    forKey: .height),
            width:       try c.decode(Int.self,    forKey: .width),
            downloadUrl: try c.decode(String.self, forKey: .downloadUrl)
        )
    }
}

// MARK: - DocumentListItem

/// A summary item in a paginated documents list.
@objcMembers
public final class DocumentListItem: NSObject {
    public let id: String
    public let name: String
    public let status: DocumentStatus
    public let statusString: String
    public let accountId: String?
    public let templateId: String?
    public let createdAt: String
    public let updatedAt: String?
    public let isClosed: Bool
    public let declineReason: String?

    init(id: String, name: String, status: DocumentStatus, statusString: String,
         accountId: String? = nil, templateId: String? = nil,
         createdAt: String, updatedAt: String? = nil, isClosed: Bool = false,
         declineReason: String? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.statusString = statusString
        self.accountId = accountId
        self.templateId = templateId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isClosed = isClosed
        self.declineReason = declineReason
    }
}

extension DocumentListItem: @unchecked Sendable {}

extension DocumentListItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, status
        case accountId = "account_id"
        case templateId = "template_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isClosed = "is_closed"
        case declineReason = "decline_reason"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let statusString = try c.decode(String.self, forKey: .status)
        self.init(
            id:            try c.decode(String.self,        forKey: .id),
            name:          try c.decode(String.self,        forKey: .name),
            status:        DocumentStatus(string: statusString),
            statusString:  statusString,
            accountId:     try c.decodeIfPresent(String.self, forKey: .accountId),
            templateId:    try c.decodeIfPresent(String.self, forKey: .templateId),
            createdAt:     try c.decode(String.self,        forKey: .createdAt),
            updatedAt:     try c.decodeIfPresent(String.self, forKey: .updatedAt),
            isClosed:      try c.decodeIfPresent(Bool.self,   forKey: .isClosed) ?? false,
            declineReason: try c.decodeIfPresent(String.self, forKey: .declineReason)
        )
    }
}

// MARK: - DeclinedBySigner

public struct DeclinedBySigner: Decodable {
    public let id: String
    public let fullName: String
    public let email: String

    public enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
    }

    public init(id: String, fullName: String, email: String) {
        self.id = id
        self.fullName = fullName
        self.email = email
    }
}

// MARK: - DocumentUploadResponse

/// The response returned immediately after a successful document upload.
@objcMembers
public final class DocumentUploadResponse: NSObject {
    public let id: String
    public let accountId: String
    public let templateId: String?
    public let name: String
    public let status: DocumentStatus
    public let statusString: String
    public let artifacts: DocumentArtifacts
    public let pages: [DocumentPage]
    public let createdAt: String
    public let updatedAt: String
    public let isClosed: Bool
    public let declineReason: String?
    public let declinedBy: DeclinedBySigner?

    init(id: String, accountId: String, templateId: String? = nil,
         name: String, status: DocumentStatus, statusString: String,
         artifacts: DocumentArtifacts, pages: [DocumentPage],
         createdAt: String, updatedAt: String, isClosed: Bool = false,
         declineReason: String? = nil, declinedBy: DeclinedBySigner? = nil) {
        self.id = id; self.accountId = accountId; self.templateId = templateId
        self.name = name; self.status = status; self.statusString = statusString
        self.artifacts = artifacts; self.pages = pages
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.isClosed = isClosed; self.declineReason = declineReason
        self.declinedBy = declinedBy
    }
}

extension DocumentUploadResponse: @unchecked Sendable {}

extension DocumentUploadResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, status, artifacts, pages
        case accountId    = "account_id"
        case templateId   = "template_id"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
        case isClosed     = "is_closed"
        case declineReason = "decline_reason"
        case declinedBy   = "declined_by"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let statusString = try c.decode(String.self, forKey: .status)
        self.init(
            id:            try c.decode(String.self,             forKey: .id),
            accountId:     try c.decode(String.self,             forKey: .accountId),
            templateId:    try c.decodeIfPresent(String.self,    forKey: .templateId),
            name:          try c.decode(String.self,             forKey: .name),
            status:        DocumentStatus(string: statusString),
            statusString:  statusString,
            artifacts:     try c.decode(DocumentArtifacts.self,  forKey: .artifacts),
            pages:         try c.decode([DocumentPage].self,     forKey: .pages),
            createdAt:     try c.decode(String.self,             forKey: .createdAt),
            updatedAt:     try c.decode(String.self,             forKey: .updatedAt),
            isClosed:      try c.decodeIfPresent(Bool.self,      forKey: .isClosed) ?? false,
            declineReason: try c.decodeIfPresent(String.self,    forKey: .declineReason),
            declinedBy:    try c.decodeIfPresent(DeclinedBySigner.self, forKey: .declinedBy)
        )
    }
}

// MARK: - DocumentActivity

/// A single entry in a document's audit activity log.
@objcMembers
public final class DocumentActivity: NSObject {
    public let id: Int
    public let event: String
    public let message: String
    public let origin: String
    public let createdAt: String

    init(id: Int, event: String, message: String, origin: String, createdAt: String) {
        self.id = id; self.event = event; self.message = message
        self.origin = origin; self.createdAt = createdAt
    }
}

extension DocumentActivity: @unchecked Sendable {}

extension DocumentActivity: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, event, message, origin
        case createdAt = "created_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:        try c.decode(Int.self,    forKey: .id),
            event:     try c.decode(String.self, forKey: .event),
            message:   try c.decode(String.self, forKey: .message),
            origin:    try c.decode(String.self, forKey: .origin),
            createdAt: try c.decode(String.self, forKey: .createdAt)
        )
    }
}

// MARK: - DocumentDetails

/// Full details of a document, including assignment and activities.
@objcMembers
public final class DocumentDetails: NSObject {
    public let id: String
    public let accountId: String
    public let name: String
    public let status: DocumentStatus
    public let statusString: String
    public let assignment: Assignment?
    public let downloadUrl: String?
    public let signingUrl: String?
    public let artifacts: DocumentArtifacts?
    public let pages: [DocumentPage]
    public let createdAt: String
    public let updatedAt: String
    public let isClosed: Bool
    public let declineReason: String?
    public let declinedBy: DeclinedBySigner?
    public let activities: [DocumentActivity]?

    init(id: String, accountId: String, name: String, status: DocumentStatus, statusString: String,
         assignment: Assignment? = nil, downloadUrl: String? = nil,
         signingUrl: String? = nil, artifacts: DocumentArtifacts? = nil, pages: [DocumentPage] = [],
         createdAt: String, updatedAt: String, isClosed: Bool = false,
         declineReason: String? = nil, declinedBy: DeclinedBySigner? = nil,
         activities: [DocumentActivity]? = nil) {
        self.id = id; self.accountId = accountId; self.name = name
        self.status = status; self.statusString = statusString
        self.assignment = assignment; self.downloadUrl = downloadUrl
        self.signingUrl = signingUrl
        self.artifacts = artifacts; self.pages = pages
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.isClosed = isClosed; self.declineReason = declineReason
        self.declinedBy = declinedBy; self.activities = activities
    }
}

extension DocumentDetails: @unchecked Sendable {}

extension DocumentDetails: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, status, assignment, artifacts, pages, activities
        case accountId       = "account_id"
        case downloadUrl     = "download_url"
        case signingUrl      = "signing_url"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case isClosed        = "is_closed"
        case declineReason   = "decline_reason"
        case declinedBy      = "declined_by"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let statusString = try c.decode(String.self, forKey: .status)
        self.init(
            id:               try c.decode(String.self,                  forKey: .id),
            accountId:        try c.decode(String.self,                  forKey: .accountId),
            name:             try c.decode(String.self,                  forKey: .name),
            status:           DocumentStatus(string: statusString),
            statusString:     statusString,
            assignment:       try c.decodeIfPresent(Assignment.self,     forKey: .assignment),
            downloadUrl:      try c.decodeIfPresent(String.self,         forKey: .downloadUrl),
            signingUrl:       try c.decodeIfPresent(String.self,         forKey: .signingUrl),
            artifacts:        try c.decodeIfPresent(DocumentArtifacts.self, forKey: .artifacts),
            pages:            (try? c.decode([DocumentPage].self, forKey: .pages)) ?? [],
            createdAt:        try c.decode(String.self,                  forKey: .createdAt),
            updatedAt:        try c.decode(String.self,                  forKey: .updatedAt),
            isClosed:         try c.decodeIfPresent(Bool.self,           forKey: .isClosed) ?? false,
            declineReason:    try c.decodeIfPresent(String.self,         forKey: .declineReason),
            declinedBy:       try c.decodeIfPresent(DeclinedBySigner.self, forKey: .declinedBy),
            activities:       try c.decodeIfPresent([DocumentActivity].self, forKey: .activities)
        )
    }
}

// MARK: - SigningProgress

/// Signing progress summary for display in UI components.
@objcMembers
public final class SigningProgress: NSObject {
    /// The number of signers who have completed signing.
    public let signed: Int
    /// The total number of signers required.
    public let total: Int
    /// The number of signers who have not yet signed.
    public let pending: Int
    /// A value between `0.0` and `100.0` representing completion.
    public let percentage: Double

    public init(signed: Int, total: Int, pending: Int, percentage: Double) {
        self.signed = signed; self.total = total
        self.pending = pending; self.percentage = percentage
    }
}

extension SigningProgress: @unchecked Sendable {}

// MARK: - Options

/// Options for ``DocumentResource/upload(_:options:)``.
@objcMembers
public final class DocumentUploadOptions: NSObject {
    /// Override the client's default account ID.
    public var accountId: String?

    @objc public init(accountId: String? = nil) {
        self.accountId = accountId
    }
}

extension DocumentUploadOptions: @unchecked Sendable {}

// MARK: - VerifyResponse

struct VerifyResponse: Decodable {
    let isValid: Bool

    enum CodingKeys: String, CodingKey {
        case isValid  = "is_valid"
        case verified
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let valid = try c.decodeIfPresent(Bool.self, forKey: .isValid)
            ?? c.decodeIfPresent(Bool.self, forKey: .verified)
        self.isValid = valid ?? false
    }
}

/// Options for ``DocumentResource/waitUntilReady(documentId:options:)``.
@objcMembers
public final class WaitUntilReadyOptions: NSObject {
    /// Maximum time to wait before throwing a timeout error. Defaults to `30` seconds.
    public var maxWaitSeconds: TimeInterval
    /// Interval between status poll requests. Defaults to `2` seconds.
    public var pollIntervalSeconds: TimeInterval

    @objc public init(maxWaitSeconds: TimeInterval = 30, pollIntervalSeconds: TimeInterval = 2) {
        self.maxWaitSeconds = maxWaitSeconds
        self.pollIntervalSeconds = pollIntervalSeconds
    }
}

extension WaitUntilReadyOptions: @unchecked Sendable {}

// MARK: - DocumentStatusInfo

/// Metadata for a single document status returned by `GET /documents/statuses`.
@objcMembers
public final class DocumentStatusInfo: NSObject {
    /// The raw status string (e.g. `"metadata_ready"`).
    public let code: String
    /// Whether a document currently in this status may be deleted.
    public let deletable: Bool

    init(code: String, deletable: Bool) {
        self.code = code; self.deletable = deletable
    }
}

extension DocumentStatusInfo: @unchecked Sendable {}

extension DocumentStatusInfo: Decodable {
    enum CodingKeys: String, CodingKey { case code, deletable }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            code: try c.decode(String.self, forKey: .code),
            deletable: try c.decodeIfPresent(Bool.self, forKey: .deletable) ?? false
        )
    }
}

// MARK: - PublicDocumentInfo

/// The unauthenticated public view of a document returned by
/// `GET /public/documents/{document_id}`.
@objcMembers
public final class PublicDocumentInfo: NSObject {
    public let id: String
    public let name: String
    public let pageCount: Int
    public let createdBy: String?

    init(id: String, name: String, pageCount: Int, createdBy: String? = nil) {
        self.id = id; self.name = name
        self.pageCount = pageCount; self.createdBy = createdBy
    }
}

extension PublicDocumentInfo: @unchecked Sendable {}

extension PublicDocumentInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name
        case pageCount = "page_count"
        case createdBy = "created_by"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let count: Int
        if let n = try? c.decode(Int.self, forKey: .pageCount) {
            count = n
        } else if let s = try? c.decode(String.self, forKey: .pageCount), let n = Int(s) {
            count = n
        } else {
            count = 0
        }
        self.init(
            id: try c.decode(String.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            pageCount: count,
            createdBy: try c.decodeIfPresent(String.self, forKey: .createdBy)
        )
    }
}

// MARK: - SendTokenChannel

/// The delivery channel for `PUT /public/documents/{id}/send-token`.
@objc public enum SendTokenChannel: Int {
    case email = 0
    case whatsapp = 1

    var stringValue: String {
        switch self {
        case .email:    return "email"
        case .whatsapp: return "whatsapp"
        }
    }
}

/// Payload for `PUT /public/documents/{id}/send-token`.
@objcMembers
public final class SendTokenPayload: NSObject, Encodable {
    /// The recipient address (email or phone, depending on ``channel``).
    public let recipient: String
    /// The delivery channel.
    public let channel: SendTokenChannel

    @objc public init(recipient: String, channel: SendTokenChannel = .email) {
        self.recipient = recipient
        self.channel = channel
    }

    enum CodingKeys: String, CodingKey { case recipient, channel }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(recipient, forKey: .recipient)
        try c.encode(channel.stringValue, forKey: .channel)
    }
}

extension SendTokenPayload: @unchecked Sendable {}

/// Response from `PUT /public/documents/{id}/send-token`.
@objcMembers
public final class SendTokenResponse: NSObject {
    public let document: PublicDocumentInfo
    public let channel: String
    public let recipient: String

    init(document: PublicDocumentInfo, channel: String, recipient: String) {
        self.document = document
        self.channel = channel
        self.recipient = recipient
    }
}

extension SendTokenResponse: @unchecked Sendable {}

extension SendTokenResponse: Decodable {
    enum CodingKeys: String, CodingKey { case document, channel, recipient }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            document: try c.decode(PublicDocumentInfo.self, forKey: .document),
            channel: try c.decode(String.self, forKey: .channel),
            recipient: try c.decode(String.self, forKey: .recipient)
        )
    }
}
