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

    /// Creates a status from its API string, returning ``unknown`` for unrecognized values.
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
    /// The PAdES PDF containing ICP-Brasil signer signatures.
    case pades = 4
}

public extension DocumentArtifactName {
    var pathValue: String {
        switch self {
        case .original:        return "original"
        case .certificated:    return "certificated"
        case .certificatePage: return "certificate-page"
        case .pades:           return "pades"
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
    public let pades: String?
    public let bundle: String?

    init(original: String, thumbnail: String? = nil, certificated: String? = nil,
         certificatePage: String? = nil, pades: String? = nil, bundle: String? = nil) {
        self.original = original
        self.thumbnail = thumbnail
        self.certificated = certificated
        self.certificatePage = certificatePage
        self.pades = pades
        self.bundle = bundle
    }
}

extension DocumentArtifacts: @unchecked Sendable {}

extension DocumentArtifacts: Decodable {
    enum CodingKeys: String, CodingKey {
        case original, thumbnail, certificated, pades, bundle
        case certificatePage = "certificate-page"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            original:        try c.decode(String.self,         forKey: .original),
            thumbnail:       try c.decodeIfPresent(String.self, forKey: .thumbnail),
            certificated:    try c.decodeIfPresent(String.self, forKey: .certificated),
            certificatePage: try c.decodeIfPresent(String.self, forKey: .certificatePage),
            pades:           try c.decodeIfPresent(String.self, forKey: .pades),
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
    /// Resource discriminator returned by the API when present.
    public let resource: String?
    public let id: String
    public let name: String
    public let status: DocumentStatus
    public let statusString: String
    public let accountId: String?
    public let templateId: String?
    public let assignment: Assignment?
    public let artifacts: DocumentArtifacts?
    public let pages: [DocumentPage]
    public let tags: [Tag]
    public let createdAt: String
    public let updatedAt: String?
    public let isClosed: Bool
    public let declineReason: String?
    public let declinedBy: Signer?
    /// Hosted signing URL for the document, when the API provides one.
    public let signingUrl: String?

    init(resource: String? = nil, id: String, name: String,
         status: DocumentStatus, statusString: String,
         accountId: String? = nil, templateId: String? = nil,
         assignment: Assignment? = nil, artifacts: DocumentArtifacts? = nil,
         pages: [DocumentPage] = [], tags: [Tag] = [],
         createdAt: String, updatedAt: String? = nil, isClosed: Bool = false,
         declineReason: String? = nil, declinedBy: Signer? = nil,
         signingUrl: String? = nil) {
        self.resource = resource
        self.id = id
        self.name = name
        self.status = status
        self.statusString = statusString
        self.accountId = accountId
        self.templateId = templateId
        self.assignment = assignment
        self.artifacts = artifacts
        self.pages = pages
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isClosed = isClosed
        self.declineReason = declineReason
        self.declinedBy = declinedBy
        self.signingUrl = signingUrl
    }
}

extension DocumentListItem: @unchecked Sendable {}

extension DocumentListItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, name, status, assignment, artifacts, pages, tags
        case accountId = "account_id"
        case templateId = "template_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isClosed = "is_closed"
        case declineReason = "decline_reason"
        case declinedBy = "declined_by"
        case signingUrl = "signing_url"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let statusString = try c.decode(String.self, forKey: .status)
        self.init(
            resource:      try c.decodeIfPresent(String.self, forKey: .resource),
            id:            try c.decode(String.self,        forKey: .id),
            name:          try c.decode(String.self,        forKey: .name),
            status:        DocumentStatus(string: statusString),
            statusString:  statusString,
            accountId:     try c.decodeIfPresent(String.self, forKey: .accountId),
            templateId:    try c.decodeIfPresent(String.self, forKey: .templateId),
            assignment:    try c.decodeIfPresent(Assignment.self, forKey: .assignment),
            artifacts:     try c.decodeIfPresent(DocumentArtifacts.self, forKey: .artifacts),
            pages:         (try? c.decode([DocumentPage].self, forKey: .pages)) ?? [],
            tags:          (try? c.decode([Tag].self, forKey: .tags)) ?? [],
            createdAt:     try decodeFlexibleString(from: c, forKey: .createdAt),
            updatedAt:     try decodeFlexibleOptionalString(from: c, forKey: .updatedAt),
            isClosed:      try c.decodeIfPresent(Bool.self,   forKey: .isClosed) ?? false,
            declineReason: try c.decodeIfPresent(String.self, forKey: .declineReason),
            declinedBy:    try c.decodeIfPresent(Signer.self, forKey: .declinedBy),
            signingUrl:    try c.decodeIfPresent(String.self, forKey: .signingUrl)
        )
    }
}

// MARK: - DeclinedBySigner

public struct DeclinedBySigner: Decodable {
    public let id: String
    public let fullName: String
    public let email: String?

    public enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
    }

    /// Creates a compact signer identity for a declined document.
    public init(id: String, fullName: String, email: String?) {
        self.id = id
        self.fullName = fullName
        self.email = email
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            fullName: try c.decode(String.self, forKey: .fullName),
            email: try c.decodeIfPresent(String.self, forKey: .email)
        )
    }
}

// MARK: - DocumentUploadResponse

/// The response returned immediately after a successful document upload.
@objcMembers
public final class DocumentUploadResponse: NSObject {
    /// Resource discriminator returned by the API.
    public let resource: String?
    public let id: String
    public let accountId: String?
    public let templateId: String?
    public let name: String
    public let status: DocumentStatus
    public let statusString: String
    public let artifacts: DocumentArtifacts
    public let pages: [DocumentPage]
    public let createdAt: String
    public let updatedAt: String
    public let isClosed: Bool
    public let signingUrl: String?
    public let declineReason: String?
    /// Full documented signer representation for `declined_by`.
    public let declinedBySigner: Signer?
    /// Compatibility representation retained for existing integrations.
    public let declinedBy: DeclinedBySigner?
    public let tags: [Tag]
    public let assignment: Assignment?

    init(resource: String? = nil, id: String, accountId: String?, templateId: String? = nil,
         name: String, status: DocumentStatus, statusString: String,
         artifacts: DocumentArtifacts, pages: [DocumentPage],
         createdAt: String, updatedAt: String, isClosed: Bool = false,
         signingUrl: String? = nil, declineReason: String? = nil,
         declinedBySigner: Signer? = nil, declinedBy: DeclinedBySigner? = nil,
         tags: [Tag] = [], assignment: Assignment? = nil) {
        self.resource = resource
        self.id = id; self.accountId = accountId; self.templateId = templateId
        self.name = name; self.status = status; self.statusString = statusString
        self.artifacts = artifacts; self.pages = pages
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.isClosed = isClosed; self.signingUrl = signingUrl
        self.declineReason = declineReason
        self.declinedBySigner = declinedBySigner
        self.declinedBy = declinedBy
        self.tags = tags
        self.assignment = assignment
    }
}

extension DocumentUploadResponse: @unchecked Sendable {}

extension DocumentUploadResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, name, status, artifacts, pages, tags, assignment
        case accountId    = "account_id"
        case templateId   = "template_id"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
        case isClosed     = "is_closed"
        case signingUrl   = "signing_url"
        case declineReason = "decline_reason"
        case declinedBy   = "declined_by"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let statusString = try c.decode(String.self, forKey: .status)
        let declinedBySigner = try c.decodeIfPresent(Signer.self, forKey: .declinedBy)
        self.init(
            resource:      try c.decodeIfPresent(String.self, forKey: .resource),
            id:            try c.decode(String.self,             forKey: .id),
            accountId:     try c.decodeIfPresent(String.self,    forKey: .accountId),
            templateId:    try c.decodeIfPresent(String.self,    forKey: .templateId),
            name:          try c.decode(String.self,             forKey: .name),
            status:        DocumentStatus(string: statusString),
            statusString:  statusString,
            artifacts:     try c.decode(DocumentArtifacts.self,  forKey: .artifacts),
            pages:         (try? c.decode([DocumentPage].self, forKey: .pages)) ?? [],
            createdAt:     try decodeFlexibleString(from: c, forKey: .createdAt),
            updatedAt:     try decodeFlexibleString(from: c, forKey: .updatedAt),
            isClosed:      try c.decodeIfPresent(Bool.self,      forKey: .isClosed) ?? false,
            signingUrl:    try c.decodeIfPresent(String.self,    forKey: .signingUrl),
            declineReason: try c.decodeIfPresent(String.self,    forKey: .declineReason),
            declinedBySigner: declinedBySigner,
            declinedBy: declinedBySigner.map {
                DeclinedBySigner(id: $0.id, fullName: $0.fullName, email: $0.email)
            },
            tags:          (try? c.decode([Tag].self, forKey: .tags)) ?? [],
            assignment:    try c.decodeIfPresent(Assignment.self, forKey: .assignment)
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
    public let payload: String?
    public let createdAt: String

    init(id: Int, event: String, message: String, origin: String, payload: String? = nil, createdAt: String) {
        self.id = id; self.event = event; self.message = message
        self.origin = origin; self.payload = payload; self.createdAt = createdAt
    }
}

extension DocumentActivity: @unchecked Sendable {}

extension DocumentActivity: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, event, message, origin, payload
        case createdAt = "created_at"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:        try c.decode(Int.self,    forKey: .id),
            event:     try c.decode(String.self, forKey: .event),
            message:   try c.decode(String.self, forKey: .message),
            origin:    (try decodeFlexibleOptionalString(from: c, forKey: .origin)) ?? "",
            payload:   try decodeFlexibleOptionalString(from: c, forKey: .payload),
            createdAt: try decodeFlexibleString(from: c, forKey: .createdAt)
        )
    }
}

// MARK: - DocumentDetails

/// Full details of a document, including assignment and activities.
@objcMembers
public final class DocumentDetails: NSObject {
    /// Resource discriminator returned by the API.
    public let resource: String?
    public let id: String
    public let accountId: String?
    public let templateId: String?
    public let name: String
    public let status: DocumentStatus
    public let statusString: String
    public let assignment: Assignment?
    public let downloadUrl: String?
    public let downloadFinalUrl: String?
    public let signingUrl: String?
    public let artifacts: DocumentArtifacts?
    public let pages: [DocumentPage]
    public let tags: [Tag]
    public let createdAt: String
    public let updatedAt: String
    public let isClosed: Bool
    public let declineReason: String?
    /// Full documented signer representation for `declined_by`.
    public let declinedBySigner: Signer?
    /// Compatibility representation retained for existing integrations.
    public let declinedBy: DeclinedBySigner?
    public let activities: [DocumentActivity]?

    init(resource: String? = nil, id: String, accountId: String?, templateId: String? = nil,
         name: String, status: DocumentStatus, statusString: String,
         assignment: Assignment? = nil, downloadUrl: String? = nil, downloadFinalUrl: String? = nil,
         signingUrl: String? = nil, artifacts: DocumentArtifacts? = nil, pages: [DocumentPage] = [],
         tags: [Tag] = [],
         createdAt: String, updatedAt: String, isClosed: Bool = false,
         declineReason: String? = nil, declinedBySigner: Signer? = nil,
         declinedBy: DeclinedBySigner? = nil,
         activities: [DocumentActivity]? = nil) {
        self.resource = resource
        self.id = id; self.accountId = accountId; self.templateId = templateId; self.name = name
        self.status = status; self.statusString = statusString
        self.assignment = assignment; self.downloadUrl = downloadUrl
        self.downloadFinalUrl = downloadFinalUrl
        self.signingUrl = signingUrl
        self.artifacts = artifacts; self.pages = pages; self.tags = tags
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.isClosed = isClosed; self.declineReason = declineReason
        self.declinedBySigner = declinedBySigner
        self.declinedBy = declinedBy; self.activities = activities
    }
}

extension DocumentDetails: @unchecked Sendable {}

extension DocumentDetails: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, name, status, assignment, artifacts, pages, activities
        case accountId       = "account_id"
        case templateId      = "template_id"
        case downloadUrl     = "download_url"
        case downloadFinalUrl = "download_final_url"
        case signingUrl      = "signing_url"
        case tags
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case isClosed        = "is_closed"
        case declineReason   = "decline_reason"
        case declinedBy      = "declined_by"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let statusString = try c.decode(String.self, forKey: .status)
        let declinedBySigner = try c.decodeIfPresent(Signer.self, forKey: .declinedBy)
        self.init(
            resource:         try c.decodeIfPresent(String.self, forKey: .resource),
            id:               try c.decode(String.self,                  forKey: .id),
            accountId:        try c.decodeIfPresent(String.self,         forKey: .accountId),
            templateId:       try c.decodeIfPresent(String.self,         forKey: .templateId),
            name:             try c.decode(String.self,                  forKey: .name),
            status:           DocumentStatus(string: statusString),
            statusString:     statusString,
            assignment:       try c.decodeIfPresent(Assignment.self,     forKey: .assignment),
            downloadUrl:      try c.decodeIfPresent(String.self,         forKey: .downloadUrl),
            downloadFinalUrl: try c.decodeIfPresent(String.self,         forKey: .downloadFinalUrl),
            signingUrl:       try c.decodeIfPresent(String.self,         forKey: .signingUrl),
            artifacts:        try c.decodeIfPresent(DocumentArtifacts.self, forKey: .artifacts),
            pages:            (try? c.decode([DocumentPage].self, forKey: .pages)) ?? [],
            tags:             (try? c.decode([Tag].self, forKey: .tags)) ?? [],
            createdAt:        try decodeFlexibleString(from: c, forKey: .createdAt),
            updatedAt:        try decodeFlexibleString(from: c, forKey: .updatedAt),
            isClosed:         try c.decodeIfPresent(Bool.self,           forKey: .isClosed) ?? false,
            declineReason:    try c.decodeIfPresent(String.self,         forKey: .declineReason),
            declinedBySigner: declinedBySigner,
            declinedBy: declinedBySigner.map {
                DeclinedBySigner(id: $0.id, fullName: $0.fullName, email: $0.email)
            },
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

    /// Creates a signing-progress summary from signer counts and completion percentage.
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

    /// Creates upload options with an optional account override.
    @objc public init(accountId: String? = nil) {
        self.accountId = accountId
    }
}

extension DocumentUploadOptions: @unchecked Sendable {}

// MARK: - DocumentListParams

/// Query parameters for `GET /accounts/{account_id}/documents`.
@objcMembers
public final class DocumentListParams: NSObject {
    public var status: String?
    public var method: String?
    public var search: String?
    public var tagIds: [String]
    public var sort: String?
    public var page: Int
    public var perPage: Int

    /// Creates document-list filters and pagination options.
    /// - Parameters:
    ///   - status: Optional document status filter.
    ///   - method: Optional assignment-method filter.
    ///   - search: Optional free-text search term.
    ///   - tagIds: Tag IDs that documents must match.
    ///   - sort: Optional API sort expression.
    ///   - page: One-based page number; zero omits the parameter.
    ///   - perPage: Page size; zero omits the parameter.
    @objc public init(
        status: String? = nil,
        method: String? = nil,
        search: String? = nil,
        tagIds: [String] = [],
        sort: String? = nil,
        page: Int = 0,
        perPage: Int = 0
    ) {
        self.status = status
        self.method = method
        self.search = search
        self.tagIds = tagIds
        self.sort = sort
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
        if !tagIds.isEmpty { items.append(.init(name: "tags", value: tagIds.joined(separator: ","))) }
        if let sort, !sort.isEmpty { items.append(.init(name: "sort", value: sort)) }
        return items
    }
}

extension DocumentListParams: @unchecked Sendable {}

// MARK: - DocumentVerification

/// Certification details returned by `GET /documents/{signatureHash}/verify`.
///
/// When the hash does not identify a certificated document, ``isValid`` is
/// `false` and the nullable certification fields are absent.
@objcMembers
public final class DocumentVerification: NSObject {
    /// Signature hash that was checked.
    public let signatureHash: String?
    /// Matching document ID, when found.
    public let id: String?
    /// Raw document status, when found.
    public let status: String?
    /// Number of pages, represented as a string by the API.
    public let pageCount: String?
    /// Number of required signers, represented as a string by the API.
    public let signerCount: String?
    /// Number of completed signers.
    public let completedCount: Int?
    /// ISO-8601 time at which signing completed.
    public let completedAt: String?
    /// ISO-8601 time at which verification was performed.
    public let verifiedAt: String?
    /// Whether the document and its certification are valid.
    public let isValid: Bool
    /// Human-readable explanation, especially when ``isValid`` is `false`.
    public let message: String?

    /// Creates a document-verification result.
    /// - Parameters:
    ///   - signatureHash: Hash checked by the verification endpoint.
    ///   - id: Matching document ID.
    ///   - status: Matching document status.
    ///   - pageCount: Page count returned by the API.
    ///   - signerCount: Required signer count returned by the API.
    ///   - completedCount: Number of completed signers.
    ///   - completedAt: ISO-8601 signing completion time.
    ///   - verifiedAt: ISO-8601 verification time.
    ///   - isValid: Whether certification is valid.
    ///   - message: Verification explanation.
    public init(
        signatureHash: String? = nil,
        id: String? = nil,
        status: String? = nil,
        pageCount: String? = nil,
        signerCount: String? = nil,
        completedCount: Int? = nil,
        completedAt: String? = nil,
        verifiedAt: String? = nil,
        isValid: Bool,
        message: String? = nil
    ) {
        self.signatureHash = signatureHash
        self.id = id
        self.status = status
        self.pageCount = pageCount
        self.signerCount = signerCount
        self.completedCount = completedCount
        self.completedAt = completedAt
        self.verifiedAt = verifiedAt
        self.isValid = isValid
        self.message = message
    }
}

extension DocumentVerification: @unchecked Sendable {}

extension DocumentVerification: Decodable {
    enum CodingKeys: String, CodingKey {
        case signatureHash = "hash"
        case id, status, message, verified
        case pageCount = "page_count"
        case signerCount = "signer_count"
        case completedCount = "completed_count"
        case completedAt = "completed_at"
        case verifiedAt = "verified_at"
        case isValid = "is_valid"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let isValid = try c.decodeIfPresent(Bool.self, forKey: .isValid)
            ?? c.decodeIfPresent(Bool.self, forKey: .verified)
            ?? false
        self.init(
            signatureHash: try c.decodeIfPresent(String.self, forKey: .signatureHash),
            id: try c.decodeIfPresent(String.self, forKey: .id),
            status: try c.decodeIfPresent(String.self, forKey: .status),
            pageCount: try decodeFlexibleOptionalString(from: c, forKey: .pageCount),
            signerCount: try decodeFlexibleOptionalString(from: c, forKey: .signerCount),
            completedCount: try c.decodeIfPresent(Int.self, forKey: .completedCount),
            completedAt: try decodeFlexibleOptionalString(from: c, forKey: .completedAt),
            verifiedAt: try decodeFlexibleOptionalString(from: c, forKey: .verifiedAt),
            isValid: isValid,
            message: try c.decodeIfPresent(String.self, forKey: .message)
        )
    }
}

/// Options for ``DocumentResource/waitUntilReady(documentId:options:)``.
@objcMembers
public final class WaitUntilReadyOptions: NSObject {
    /// Maximum time to wait before throwing a timeout error. Defaults to `30` seconds.
    public var maxWaitSeconds: TimeInterval
    /// Interval between status poll requests. Defaults to `2` seconds.
    public var pollIntervalSeconds: TimeInterval

    /// Creates polling options.
    /// - Parameters:
    ///   - maxWaitSeconds: Maximum total wait in seconds.
    ///   - pollIntervalSeconds: Delay between status requests in seconds.
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

/// The complete unauthenticated document returned by
/// `GET /public/documents/{document_id}`.
///
/// The legacy ``pageCount`` and ``createdBy`` properties remain available for
/// older integrations. Current responses populate the same document fields as
/// authenticated document endpoints.
@objcMembers
public final class PublicDocumentInfo: NSObject {
    /// Resource discriminator returned for single-resource responses.
    public let resource: String?
    public let id: String
    public let accountId: String?
    public let templateId: String?
    public let name: String
    public let status: DocumentStatus
    public let statusString: String
    public let artifacts: DocumentArtifacts?
    public let isClosed: Bool
    public let signingUrl: String?
    public let declineReason: String?
    public let declinedBy: Signer?
    public let tags: [Tag]
    public let assignment: Assignment?
    public let pages: [DocumentPage]
    public let createdAt: String?
    public let updatedAt: String?

    /// Legacy page-count field. Current responses derive this from ``pages``.
    public let pageCount: Int
    /// Legacy creator display name, when an older API response supplies it.
    public let createdBy: String?

    init(
        resource: String? = nil,
        id: String,
        accountId: String? = nil,
        templateId: String? = nil,
        name: String,
        status: DocumentStatus = .unknown,
        statusString: String = "unknown",
        artifacts: DocumentArtifacts? = nil,
        isClosed: Bool = false,
        signingUrl: String? = nil,
        declineReason: String? = nil,
        declinedBy: Signer? = nil,
        tags: [Tag] = [],
        assignment: Assignment? = nil,
        pages: [DocumentPage] = [],
        createdAt: String? = nil,
        updatedAt: String? = nil,
        pageCount: Int? = nil,
        createdBy: String? = nil
    ) {
        self.resource = resource
        self.id = id
        self.accountId = accountId
        self.templateId = templateId
        self.name = name
        self.status = status
        self.statusString = statusString
        self.artifacts = artifacts
        self.isClosed = isClosed
        self.signingUrl = signingUrl
        self.declineReason = declineReason
        self.declinedBy = declinedBy
        self.tags = tags
        self.assignment = assignment
        self.pages = pages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pageCount = pageCount ?? pages.count
        self.createdBy = createdBy
    }
}

extension PublicDocumentInfo: @unchecked Sendable {}

extension PublicDocumentInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case resource, id, name, status, artifacts, tags, assignment, pages
        case accountId = "account_id"
        case templateId = "template_id"
        case isClosed = "is_closed"
        case signingUrl = "signing_url"
        case declineReason = "decline_reason"
        case declinedBy = "declined_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pageCount = "page_count"
        case createdBy = "created_by"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let pages = (try? c.decode([DocumentPage].self, forKey: .pages)) ?? []
        let count = (try? c.decode(Int.self, forKey: .pageCount))
            ?? (try? c.decode(String.self, forKey: .pageCount)).flatMap(Int.init)
        let statusString = try c.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        self.init(
            resource: try c.decodeIfPresent(String.self, forKey: .resource),
            id: try c.decode(String.self, forKey: .id),
            accountId: try c.decodeIfPresent(String.self, forKey: .accountId),
            templateId: try c.decodeIfPresent(String.self, forKey: .templateId),
            name: try c.decode(String.self, forKey: .name),
            status: DocumentStatus(string: statusString),
            statusString: statusString,
            artifacts: try c.decodeIfPresent(DocumentArtifacts.self, forKey: .artifacts),
            isClosed: try c.decodeIfPresent(Bool.self, forKey: .isClosed) ?? false,
            signingUrl: try c.decodeIfPresent(String.self, forKey: .signingUrl),
            declineReason: try c.decodeIfPresent(String.self, forKey: .declineReason),
            declinedBy: try c.decodeIfPresent(Signer.self, forKey: .declinedBy),
            tags: (try? c.decode([Tag].self, forKey: .tags)) ?? [],
            assignment: try c.decodeIfPresent(Assignment.self, forKey: .assignment),
            pages: pages,
            createdAt: try decodeFlexibleOptionalString(from: c, forKey: .createdAt),
            updatedAt: try decodeFlexibleOptionalString(from: c, forKey: .updatedAt),
            pageCount: count,
            createdBy: try c.decodeIfPresent(String.self, forKey: .createdBy)
        )
    }
}

/// Preferred Swift name for the public document response model.
public typealias PublicDocument = PublicDocumentInfo

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
///
/// Production documents `{ "email": "..." }`. When ``channel`` is `.whatsapp`,
/// the SDK also sends the compatibility `channel` field.
@objcMembers
public final class SendTokenPayload: NSObject, Encodable {
    /// The recipient address (email address, or phone number for WhatsApp).
    public let recipient: String
    /// The delivery channel.
    public let channel: SendTokenChannel

    /// Creates a public signing-token delivery payload.
    /// - Parameters:
    ///   - recipient: Email address or WhatsApp number receiving the token.
    ///   - channel: Delivery channel.
    @objc public init(recipient: String, channel: SendTokenChannel = .email) {
        self.recipient = recipient
        self.channel = channel
    }

    enum CodingKeys: String, CodingKey { case email, channel }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // The documented field is `email`; carry the recipient there.
        try c.encode(recipient, forKey: .email)
        if channel != .email {
            try c.encode(channel.stringValue, forKey: .channel)
        }
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
