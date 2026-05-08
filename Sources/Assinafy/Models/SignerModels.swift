import Foundation

// MARK: - Signer

/// A signer registered in a workspace.
@objcMembers
public final class Signer: NSObject {
    public let id: String
    public let fullName: String
    public let email: String
    public let whatsappPhoneNumber: String?
    public let cpf: String?
    public let hasAcceptedTerms: Bool

    init(id: String, fullName: String, email: String,
         whatsappPhoneNumber: String? = nil, cpf: String? = nil, hasAcceptedTerms: Bool = false) {
        self.id = id; self.fullName = fullName; self.email = email
        self.whatsappPhoneNumber = whatsappPhoneNumber; self.cpf = cpf
        self.hasAcceptedTerms = hasAcceptedTerms
    }

    public override var description: String {
        "Signer(id: \(id), email: \(email))"
    }
}

extension Signer: @unchecked Sendable {}

extension Signer: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, email, cpf
        case fullName            = "full_name"
        case whatsappPhoneNumber = "whatsapp_phone_number"
        case hasAcceptedTerms    = "has_accepted_terms"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:                   try c.decode(String.self,           forKey: .id),
            fullName:             try c.decode(String.self,           forKey: .fullName),
            email:                try c.decode(String.self,           forKey: .email),
            whatsappPhoneNumber:  try c.decodeIfPresent(String.self,  forKey: .whatsappPhoneNumber),
            cpf:                  try c.decodeIfPresent(String.self,  forKey: .cpf),
            hasAcceptedTerms:     try c.decodeIfPresent(Bool.self,    forKey: .hasAcceptedTerms) ?? false
        )
    }
}

// MARK: - CreateSignerPayload

/// Payload for creating a new signer in the workspace.
///
/// ``signers/create(_:accountId:)`` is idempotent by email — if a signer with
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
    /// The signer's email address. Must be a valid RFC-5322 address.
    public let email: String
    /// The signer's WhatsApp-enabled phone number in E.164 format.
    public let whatsappPhoneNumber: String?
    /// The signer's Brazilian CPF. Non-digit characters are stripped automatically.
    public let cpf: String?

    /// Creates a new signer payload.
    ///
    /// - Parameters:
    ///   - fullName: The signer's full display name.
    ///   - email: A valid email address.
    ///   - whatsappPhoneNumber: E.164 phone number for WhatsApp notifications.
    ///   - cpf: Optional Brazilian CPF; non-digit characters are stripped.
    @objc public init(
        fullName: String,
        email: String,
        whatsappPhoneNumber: String? = nil,
        cpf: String? = nil
    ) {
        self.fullName = fullName
        self.email = email
        self.whatsappPhoneNumber = whatsappPhoneNumber
        let stripped = cpf?.filter(\.isNumber) ?? ""
        self.cpf = stripped.isEmpty ? nil : stripped
    }

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case email
        case whatsappPhoneNumber = "whatsapp_phone_number"
        case cpf
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fullName, forKey: .fullName)
        try c.encode(email, forKey: .email)
        try c.encodeIfPresent(whatsappPhoneNumber, forKey: .whatsappPhoneNumber)
        try c.encodeIfPresent(cpf, forKey: .cpf)
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
    public let cpf: String?

    @objc public init(
        fullName: String? = nil,
        email: String? = nil,
        whatsappPhoneNumber: String? = nil,
        cpf: String? = nil
    ) {
        self.fullName = fullName
        self.email = email
        self.whatsappPhoneNumber = whatsappPhoneNumber
        let stripped = cpf?.filter(\.isNumber) ?? ""
        self.cpf = stripped.isEmpty ? nil : stripped
    }

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case email
        case whatsappPhoneNumber = "whatsapp_phone_number"
        case cpf
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(fullName, forKey: .fullName)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(whatsappPhoneNumber, forKey: .whatsappPhoneNumber)
        try c.encodeIfPresent(cpf, forKey: .cpf)
    }
}

extension UpdateSignerPayload: @unchecked Sendable {}

// MARK: - SignerSelfInfo

/// Signer information returned by the self-service endpoint.
///
/// Includes additional fields beyond the base ``Signer`` model.
@objcMembers
public final class SignerSelfInfo: NSObject {
    public let id: String
    public let fullName: String
    public let email: String
    public let whatsappPhoneNumber: String?
    public let hasAcceptedTerms: Bool
    public let hasSignature: Bool
    public let hasInitial: Bool

    init(id: String, fullName: String, email: String, whatsappPhoneNumber: String? = nil,
         hasAcceptedTerms: Bool, hasSignature: Bool, hasInitial: Bool) {
        self.id = id; self.fullName = fullName; self.email = email
        self.whatsappPhoneNumber = whatsappPhoneNumber
        self.hasAcceptedTerms = hasAcceptedTerms
        self.hasSignature = hasSignature; self.hasInitial = hasInitial
    }
}

extension SignerSelfInfo: @unchecked Sendable {}

extension SignerSelfInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, email
        case fullName            = "full_name"
        case whatsappPhoneNumber = "whatsapp_phone_number"
        case hasAcceptedTerms   = "has_accepted_terms"
        case hasSignature       = "has_signature"
        case hasInitial         = "has_initial"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:                   try c.decode(String.self, forKey: .id),
            fullName:             try c.decode(String.self, forKey: .fullName),
            email:                try c.decode(String.self, forKey: .email),
            whatsappPhoneNumber:  try c.decodeIfPresent(String.self, forKey: .whatsappPhoneNumber),
            hasAcceptedTerms:    try c.decodeIfPresent(Bool.self, forKey: .hasAcceptedTerms) ?? false,
            hasSignature:        try c.decodeIfPresent(Bool.self, forKey: .hasSignature) ?? false,
            hasInitial:          try c.decodeIfPresent(Bool.self, forKey: .hasInitial) ?? false
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
        try c.encode(signerAccessCode, forKey: .signerAccessCode)
    }
}

extension VerifyEmailPayload: @unchecked Sendable {}

// MARK: - ConfirmSignerDataPayload

/// Payload for confirming signer data in a virtual assignment.
@objcMembers
public final class ConfirmSignerDataPayload: NSObject, Encodable {
    public let email: String?
    public let whatsappPhoneNumber: String?
    public let hasAcceptedTerms: Bool

    @objc public init(email: String? = nil, whatsappPhoneNumber: String? = nil, hasAcceptedTerms: Bool = false) {
        self.email = email
        self.whatsappPhoneNumber = whatsappPhoneNumber
        self.hasAcceptedTerms = hasAcceptedTerms
    }

    enum CodingKeys: String, CodingKey {
        case email
        case whatsappPhoneNumber = "whatsapp_phone_number"
        case hasAcceptedTerms   = "has_accepted_terms"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(whatsappPhoneNumber, forKey: .whatsappPhoneNumber)
        try c.encode(hasAcceptedTerms, forKey: .hasAcceptedTerms)
    }
}

extension ConfirmSignerDataPayload: @unchecked Sendable {}

// MARK: - SignatureType

/// The type of signature image.
@objc public enum SignatureType: Int {
    case signature = 0
    case initial = 1

    var stringValue: String {
        switch self {
        case .signature: return "signature"
        case .initial:   return "initial"
        }
    }
}
