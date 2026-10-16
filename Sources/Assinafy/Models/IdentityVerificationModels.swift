import Foundation

/// The signer-facing state of a hosted identity-document and face-match session.
@objcMembers
public final class IdentityVerificationState: NSObject, Decodable, @unchecked Sendable {
    /// True before a session exists or after its capture link expires.
    public let canStart: Bool
    /// Pending, InReview, Approved, Declined, Expired, or Abandoned; absent before starting.
    public let status: String?
    /// Sensitive capture link. Open unchanged, including its fragment; never log it.
    public let url: String?
    public let expiresAt: String?
    public let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case canStart = "can_start", status, url
        case expiresAt = "expires_at", completedAt = "completed_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        canStart = try c.decodeIfPresent(Bool.self, forKey: .canStart) ?? false
        status = try c.decodeIfPresent(String.self, forKey: .status)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt)
        super.init()
    }
}

/// The hosted session opened after the signer explicitly consents to biometric processing.
@objcMembers
public final class IdentityVerificationSession: NSObject, Decodable, @unchecked Sendable {
    public let id: String
    /// Sensitive capture link. Preserve the fragment and do not log or persist it.
    public let url: String
    public let expiresAt: String?

    enum CodingKeys: String, CodingKey { case id, url, expiresAt = "expires_at" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        url = try c.decode(String.self, forKey: .url)
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
        super.init()
    }
}

/// Explicit signer consent for `POST /signers/identity-verification`.
@objcMembers
public final class StartIdentityVerificationPayload: NSObject, Encodable, @unchecked Sendable {
    public let consent: Bool

    /// Pass true only after the signer consents to biometric processing.
    public init(consent: Bool) { self.consent = consent }
}

/// Workspace decision for an InReview verification. Rejection cancels the document.
@objcMembers
public final class ReviewIdentityVerificationPayload: NSObject, Encodable, @unchecked Sendable {
    /// Exactly `Approved` or `Rejected`.
    public let decision: String
    /// Up to 2,000 characters; visible to the provider and activity log, never the signer.
    public let note: String?

    public init(decision: String, note: String? = nil) {
        self.decision = decision
        self.note = note
    }
}

/// Identity evidence and the workspace's review decision; images are downloaded separately.
@objcMembers
public final class SignerIdentityReview: NSObject, Decodable, @unchecked Sendable {
    public let id: String
    public let status: String
    public let provider: String
    public let verificationMethod: String
    public let reasonCodes: [IdentityReviewReason]
    public let evidenceAvailable: Bool
    public let expected: IdentityReviewPerson?
    public let document: IdentityReviewPerson?
    public let matches: IdentityReviewMatches?
    public let checks: [IdentityReviewCheck]
    /// Evidence names available only while the review is open.
    public let images: [String]
    public let rulesetVersion: String?
    public let evidenceSHA256: String?
    public let reviewedBy: IdentityReviewUser?
    public let reviewedAt: String?
    public let reviewNote: String?
    public let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, provider, expected, document, matches, checks, images
        case verificationMethod = "verification_method", reasonCodes = "reason_codes"
        case evidenceAvailable = "evidence_available", rulesetVersion = "ruleset_version"
        case evidenceSHA256 = "evidence_sha256", reviewedBy = "reviewed_by"
        case reviewedAt = "reviewed_at", reviewNote = "review_note", completedAt = "completed_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? ""
        verificationMethod = try c.decodeIfPresent(String.self, forKey: .verificationMethod) ?? ""
        reasonCodes = try c.decodeIfPresent([IdentityReviewReason].self, forKey: .reasonCodes) ?? []
        evidenceAvailable = try c.decodeIfPresent(Bool.self, forKey: .evidenceAvailable) ?? false
        expected = try c.decodeIfPresent(IdentityReviewPerson.self, forKey: .expected)
        document = try c.decodeIfPresent(IdentityReviewPerson.self, forKey: .document)
        matches = try c.decodeIfPresent(IdentityReviewMatches.self, forKey: .matches)
        checks = try c.decodeIfPresent([IdentityReviewCheck].self, forKey: .checks) ?? []
        images = try c.decodeIfPresent([String].self, forKey: .images) ?? []
        rulesetVersion = try c.decodeIfPresent(String.self, forKey: .rulesetVersion)
        evidenceSHA256 = try c.decodeIfPresent(String.self, forKey: .evidenceSHA256)
        reviewedBy = try c.decodeIfPresent(IdentityReviewUser.self, forKey: .reviewedBy)
        reviewedAt = try c.decodeIfPresent(String.self, forKey: .reviewedAt)
        reviewNote = try c.decodeIfPresent(String.self, forKey: .reviewNote)
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt)
        super.init()
    }
}

/// A provider reason for sending the verification to review, in provider order.
@objcMembers
public final class IdentityReviewReason: NSObject, Decodable, @unchecked Sendable {
    public let code: String
    public let reasonDescription: String

    enum CodingKeys: String, CodingKey { case code, reasonDescription = "description" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
        reasonDescription = try c.decodeIfPresent(String.self, forKey: .reasonDescription) ?? code
        super.init()
    }
}

/// Identity registered for the signer or read from their document.
@objcMembers
public final class IdentityReviewPerson: NSObject, Decodable, @unchecked Sendable {
    /// Document type, present only on the identity read from the document.
    public let type: String?
    public let name: String?
    public let cpf: String?
}

/// Match results; NSNumber preserves an absent result for Objective-C callers.
@objcMembers
public final class IdentityReviewMatches: NSObject, Decodable, @unchecked Sendable {
    public let cpf: NSNumber?
    /// Name similarity from zero to one.
    public let name: NSNumber?
    public let birthDate: NSNumber?

    enum CodingKeys: String, CodingKey { case cpf, name, birthDate = "birth_date" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cpf = try c.decodeIfPresent(Bool.self, forKey: .cpf).map { NSNumber(value: $0) }
        name = try c.decodeIfPresent(Double.self, forKey: .name).map { NSNumber(value: $0) }
        birthDate = try c.decodeIfPresent(Bool.self, forKey: .birthDate).map { NSNumber(value: $0) }
        super.init()
    }
}

/// One provider check, including its score and reason codes when supplied.
@objcMembers
public final class IdentityReviewCheck: NSObject, Decodable, @unchecked Sendable {
    public let name: String
    public let result: String
    public let score: NSNumber?
    public let reasons: [String]

    enum CodingKeys: String, CodingKey { case name, result, score, reasons }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        result = try c.decodeIfPresent(String.self, forKey: .result) ?? ""
        score = try c.decodeIfPresent(Double.self, forKey: .score).map { NSNumber(value: $0) }
        reasons = try c.decodeIfPresent([String].self, forKey: .reasons) ?? []
        super.init()
    }
}

/// The workspace user who decided the review.
@objcMembers
public final class IdentityReviewUser: NSObject, Decodable, @unchecked Sendable {
    public let id: String?
    public let name: String?
}
