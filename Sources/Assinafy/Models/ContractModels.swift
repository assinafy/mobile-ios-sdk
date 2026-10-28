import Foundation

/// A contract's identifier in another system. Sending a list replaces all existing references.
@objcMembers
public final class ContractExternalReference: NSObject, Codable, @unchecked Sendable {
    /// System name, such as `hubspot`; the API stores it in lowercase.
    public let system: String
    /// The external identifier, preserved as sent.
    public let id: String

    /// Creates an external reference.
    public init(system: String, id: String) {
        self.system = system
        self.id = id
    }

    enum CodingKeys: String, CodingKey { case system, id }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        system = try c.decodeIfPresent(String.self, forKey: .system) ?? ""
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        super.init()
    }
}

/// Contract terms tracked on a document, optionally including its document and amendments.
@objcMembers
public final class DocumentContract: NSObject, Decodable, @unchecked Sendable {
    /// Resource discriminator, when supplied.
    public let resource: String?
    /// The document carrying these terms.
    public let documentId: String?
    /// `draft`, `active`, `expired`, or `terminated`; future values are preserved.
    public let status: String?
    /// Counterparty display name.
    public let counterpartyName: String?
    /// Counterparty CPF/CNPJ, digits only.
    public let counterpartyTaxpayerId: String?
    /// Monetary amount decoded as a decimal, without a binary floating-point conversion.
    public let value: NSDecimalNumber?
    /// ISO 4217 currency; normally `BRL` when a value exists.
    public let currency: String?
    /// Contract start date in `YYYY-MM-DD` form.
    public let startDate: String?
    /// Contract end date in `YYYY-MM-DD` form.
    public let endDate: String?
    /// Whether the lifecycle renews the contract automatically after its end date.
    public let autoRenew: Bool
    /// Months added for automatic or term-based renewal; the server uses 12 when unset.
    public let renewalTermMonths: NSNumber?
    /// Days before expiry when renewal notices begin.
    public let noticePeriodDays: NSNumber?
    /// Current term number, starting at 1 and incremented on renewal.
    public let term: NSNumber?
    /// Workspace member responsible for the contract.
    public let ownerId: String?
    /// Application-owned text fields; absent or null when none exist.
    public let metadata: [String: String]?
    /// References in other systems, ordered by system and identifier.
    public let externalReferences: [ContractExternalReference]
    /// Embedded document, present only when requested with `expand=document`.
    public let document: DocumentDetails?
    /// Linked instruments, included by the single-contract and related-family routes.
    public let amendments: [DocumentContractAmendment]
    /// Creation timestamp as returned by the API.
    public let createdAt: String?
    /// Last change timestamp; send it on a write to detect concurrent changes.
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case resource, status, value, currency, term, metadata, document, amendments
        case documentId = "document_id", counterpartyName = "counterparty_name"
        case counterpartyTaxpayerId = "counterparty_taxpayer_id"
        case startDate = "start_date", endDate = "end_date", autoRenew = "auto_renew"
        case renewalTermMonths = "renewal_term_months", noticePeriodDays = "notice_period_days"
        case ownerId = "owner_id", externalReferences = "external_references"
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        resource = try c.decodeIfPresent(String.self, forKey: .resource)
        documentId = try c.decodeIfPresent(String.self, forKey: .documentId)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        counterpartyName = try c.decodeIfPresent(String.self, forKey: .counterpartyName)
        counterpartyTaxpayerId = try c.decodeIfPresent(String.self, forKey: .counterpartyTaxpayerId)
        value = try c.decodeIfPresent(Decimal.self, forKey: .value).map(NSDecimalNumber.init(decimal:))
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try c.decodeIfPresent(String.self, forKey: .endDate)
        autoRenew = try c.decodeIfPresent(Bool.self, forKey: .autoRenew) ?? false
        renewalTermMonths = try c.decodeIfPresent(Int.self, forKey: .renewalTermMonths).map(NSNumber.init(value:))
        noticePeriodDays = try c.decodeIfPresent(Int.self, forKey: .noticePeriodDays).map(NSNumber.init(value:))
        term = try c.decodeIfPresent(Int.self, forKey: .term).map(NSNumber.init(value:))
        ownerId = try c.decodeIfPresent(String.self, forKey: .ownerId)
        metadata = try c.decodeIfPresent([String: String].self, forKey: .metadata)
        externalReferences = try c.decodeIfPresent([ContractExternalReference].self, forKey: .externalReferences) ?? []
        document = try c.decodeIfPresent(DocumentDetails.self, forKey: .document)
        amendments = try c.decodeIfPresent([DocumentContractAmendment].self, forKey: .amendments) ?? []
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        super.init()
    }
}

/// An amendment, renewal, or termination instrument linked to a root contract.
@objcMembers
public final class DocumentContractAmendment: NSObject, Decodable, @unchecked Sendable {
    /// Resource discriminator, when supplied.
    public let resource: String?
    /// The instrument's own document ID.
    public let documentId: String?
    /// The instrument's document name.
    public let documentName: String?
    /// The root contract's document ID.
    public let parentDocumentId: String?
    /// `amendment`, `renewal`, or `termination`.
    public let relationType: String?
    /// Position among applied instruments; absent while pending.
    public let number: NSNumber?
    /// `pending` or `applied`. Applied instruments are read-only.
    public let status: String?
    /// Signing status of the instrument's own document.
    public let documentStatus: String?
    /// Why a signed instrument is waiting to apply, if supplied.
    public let applyError: String?
    /// Currency of the amounts in the delta and change record.
    public let currency: String?
    /// Structured delta; only terms changed by the instrument appear here.
    @nonobjc public let termsJSON: JSONValue?
    /// Objective-C view of ``termsJSON``; JSON numbers follow ``JSONValue`` representation.
    public let terms: [String: Any]?
    /// Structured `{field: {from, to}}` preview or applied change record.
    @nonobjc public let changesJSON: JSONValue?
    /// Objective-C view of ``changesJSON``; null values are `NSNull`.
    public let changes: [String: Any]?
    /// Application timestamp, or nil while pending.
    public let appliedAt: String?
    /// Link creation timestamp.
    public let createdAt: String?
    /// Link change timestamp; use this, not the parent's timestamp, when updating the link.
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case resource, number, status, currency, terms, changes
        case documentId = "document_id", documentName = "document_name"
        case parentDocumentId = "parent_document_id", relationType = "relation_type"
        case documentStatus = "document_status", applyError = "apply_error"
        case appliedAt = "applied_at", createdAt = "created_at", updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        resource = try c.decodeIfPresent(String.self, forKey: .resource)
        documentId = try c.decodeIfPresent(String.self, forKey: .documentId)
        documentName = try c.decodeIfPresent(String.self, forKey: .documentName)
        parentDocumentId = try c.decodeIfPresent(String.self, forKey: .parentDocumentId)
        relationType = try c.decodeIfPresent(String.self, forKey: .relationType)
        number = try c.decodeIfPresent(Int.self, forKey: .number).map(NSNumber.init(value:))
        status = try c.decodeIfPresent(String.self, forKey: .status)
        documentStatus = try c.decodeIfPresent(String.self, forKey: .documentStatus)
        applyError = try c.decodeIfPresent(String.self, forKey: .applyError)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        termsJSON = try decodeJSONValue(from: c, forKey: .terms)
        terms = termsJSON?.foundationValue as? [String: Any]
        changesJSON = try decodeJSONValue(from: c, forKey: .changes)
        changes = changesJSON?.foundationValue as? [String: Any]
        appliedAt = try c.decodeIfPresent(String.self, forKey: .appliedAt)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        super.init()
    }
}

/// The result of reading or updating terms: exactly one of a root contract or an amendment.
@objcMembers
public final class ContractDetails: NSObject, Decodable, @unchecked Sendable {
    /// The root contract, when this document carries its own terms.
    public let contract: DocumentContract?
    /// The instrument link, when this document amends another contract.
    public let amendment: DocumentContractAmendment?

    enum CodingKeys: String, CodingKey { case resource, parentDocumentId = "parent_document_id" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if try c.decodeIfPresent(String.self, forKey: .resource) == "document_contract_amendment"
            || c.decodeIfPresent(String.self, forKey: .parentDocumentId) != nil {
            contract = nil
            amendment = try DocumentContractAmendment(from: decoder)
        } else {
            contract = try DocumentContract(from: decoder)
            amendment = nil
        }
        super.init()
    }
}

/// Filters for `GET /accounts/{accountId}/contracts`. Omitted filters do not restrict the list.
@objcMembers
public final class ContractListParams: NSObject, @unchecked Sendable {
    /// One or more comma-separated statuses, for example `active,expired`.
    public var status: String?
    /// Part of the counterparty name or its exact CPF/CNPJ.
    public var counterparty: String?
    /// Part of the document name.
    public var search: String?
    /// Inclusive earliest end date, `YYYY-MM-DD`.
    public var endDateFrom: String?
    /// Inclusive latest end date, `YYYY-MM-DD`.
    public var endDateTo: String?
    /// Inclusive days from today in Brasília time, from 0 through 3650.
    public var endingWithinDays: NSNumber?
    /// System of an external reference.
    public var externalSystem: String?
    /// Identifier within the external system.
    public var externalId: String?
    /// `end_date` or `updated_at`, optionally prefixed by `-`; default is `-updated_at`.
    public var sort: String?
    /// `document` embeds the document in every returned contract.
    public var expand: String?
    /// Page number, starting at 1.
    public var page: NSNumber?
    /// Page size, up to 100.
    public var perPage: NSNumber?

    /// Creates an unfiltered list request; set only the filters the application needs.
    public override init() { super.init() }

    func toQueryItems() throws -> [URLQueryItem] {
        let values: [(String, String?)] = [
            ("status", status), ("counterparty", counterparty), ("search", search),
            ("end_date_from", endDateFrom), ("end_date_to", endDateTo),
            ("ending_within_days", try contractInteger(endingWithinDays, name: "ending_within_days", range: 0...3650).map(String.init)),
            ("external_system", externalSystem), ("external_id", externalId),
            ("sort", sort), ("expand", expand),
            ("page", try contractInteger(page, name: "page", range: 1...Int.max).map(String.init)),
            ("per-page", try contractInteger(perPage, name: "per-page", range: 1...100).map(String.init)),
        ]
        return values.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
    }
}

/// Partial terms update or amendment link for `PUT /accounts/{accountId}/documents/{documentId}/contract`.
/// Nil properties are omitted. Use ``clearFields`` for explicit JSON nulls.
@objcMembers
public final class UpdateContractPayload: NSObject, Encodable, @unchecked Sendable {
    /// Initial status, or `draft`/`active` on an existing contract; lifecycle transitions are server-owned.
    public let status: String?
    /// New counterparty display name.
    public let counterpartyName: String?
    /// Formatted or unformatted CPF/CNPJ.
    public let counterpartyTaxpayerId: String?
    /// New monetary value, encoded as an exact JSON decimal.
    public let value: NSDecimalNumber?
    /// Three-letter ISO 4217 currency code.
    public let currency: String?
    /// New start date, `YYYY-MM-DD`.
    public let startDate: String?
    /// New end date, `YYYY-MM-DD`; changing it starts a new term.
    public let endDate: String?
    /// Optional boolean; nil leaves automatic renewal unchanged.
    public let autoRenew: NSNumber?
    /// Renewal interval in months, from 1 through 600.
    public let renewalTermMonths: NSNumber?
    /// Notice interval in days, from 0 through 3650.
    public let noticePeriodDays: NSNumber?
    /// Active workspace member responsible for the contract.
    public let ownerId: String?
    /// Up to 50 application-owned text fields; replaces the metadata object when sent.
    public let metadata: [String: String]?
    /// Replaces the entire list; an empty array clears it.
    public let externalReferences: [ContractExternalReference]?
    /// Links this document to a root contract or any member of its family.
    public let parentDocumentId: String?
    /// `amendment`, `renewal`, or `termination`; required by the API on first linking.
    public let relationType: String?
    /// Last-read timestamp; a concurrent change fails with `409 ContractChanged`.
    public let updatedAt: String?
    /// Wire names to encode as null. Excludes `status` and `relation_type`; conflicts with set values are rejected.
    /// On a pending amendment null drops a delta key; `parent_document_id` unlinks it.
    public let clearFields: [String]

    /// Creates a partial update. Set at least one property or explicit null field.
    public init(
        status: String? = nil, counterpartyName: String? = nil, counterpartyTaxpayerId: String? = nil,
        value: NSDecimalNumber? = nil, currency: String? = nil, startDate: String? = nil,
        endDate: String? = nil, autoRenew: NSNumber? = nil, renewalTermMonths: NSNumber? = nil,
        noticePeriodDays: NSNumber? = nil, ownerId: String? = nil, metadata: [String: String]? = nil,
        externalReferences: [ContractExternalReference]? = nil, parentDocumentId: String? = nil,
        relationType: String? = nil, updatedAt: String? = nil, clearFields: [String] = []
    ) {
        self.status = status; self.counterpartyName = counterpartyName
        self.counterpartyTaxpayerId = counterpartyTaxpayerId; self.value = value
        self.currency = currency; self.startDate = startDate; self.endDate = endDate
        self.autoRenew = autoRenew; self.renewalTermMonths = renewalTermMonths
        self.noticePeriodDays = noticePeriodDays; self.ownerId = ownerId; self.metadata = metadata
        self.externalReferences = externalReferences; self.parentDocumentId = parentDocumentId
        self.relationType = relationType; self.updatedAt = updatedAt; self.clearFields = clearFields
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case status, value, currency, metadata
        case counterpartyName = "counterparty_name", counterpartyTaxpayerId = "counterparty_taxpayer_id"
        case startDate = "start_date", endDate = "end_date", autoRenew = "auto_renew"
        case renewalTermMonths = "renewal_term_months", noticePeriodDays = "notice_period_days"
        case ownerId = "owner_id", externalReferences = "external_references"
        case parentDocumentId = "parent_document_id", relationType = "relation_type", updatedAt = "updated_at"
    }

    public func encode(to encoder: Encoder) throws {
        let clears = Set(clearFields)
        let nullable = Set(CodingKeys.allCases.filter { $0 != .status && $0 != .relationType }.map(\.rawValue))
        guard clears.isSubset(of: nullable) else { throw ValidationError("Unknown or non-nullable contract clear field") }
        var c = encoder.container(keyedBy: CodingKeys.self)
        var hasField = false
        func encode<T: Encodable>(_ value: T?, _ key: CodingKeys) throws {
            if clears.contains(key.rawValue) {
                guard value == nil else { throw ValidationError("Cannot set and clear \(key.rawValue) together") }
                try c.encodeNil(forKey: key)
                hasField = true
            } else if let value {
                try c.encode(value, forKey: key)
                hasField = true
            }
        }
        try encode(status, .status)
        try encode(counterpartyName, .counterpartyName)
        try encode(counterpartyTaxpayerId, .counterpartyTaxpayerId)
        try encode(contractDecimal(value), .value)
        try encode(currency, .currency)
        try encode(startDate, .startDate)
        try encode(endDate, .endDate)
        try encode(autoRenew?.boolValue, .autoRenew)
        try encode(contractInteger(renewalTermMonths, name: "renewal_term_months", range: 1...600), .renewalTermMonths)
        try encode(contractInteger(noticePeriodDays, name: "notice_period_days", range: 0...3650), .noticePeriodDays)
        try encode(ownerId, .ownerId)
        try encode(metadata, .metadata)
        try encode(externalReferences, .externalReferences)
        try encode(parentDocumentId, .parentDocumentId)
        try encode(relationType, .relationType)
        try encode(updatedAt, .updatedAt)
        guard hasField else { throw ValidationError("At least one contract attribute is required") }
    }
}

/// Renewal with a current term or explicit new end date, preventing an accidental second renewal.
@objcMembers
public final class RenewContractPayload: NSObject, Encodable, @unchecked Sendable {
    /// Current contract term; required when no nonempty end date is sent.
    public let term: NSNumber?
    /// New end date after the current one; nil or empty uses the configured renewal interval.
    public let endDate: String?
    /// Replacement monetary amount, or nil to keep the current value.
    public let value: NSDecimalNumber?
    /// Sends `value: null`; cannot be combined with ``value``.
    public let clearsValue: Bool
    /// Last-read timestamp; concurrent changes fail with `409`.
    public let updatedAt: String?

    /// Creates a renewal guarded by the current term or explicit end date.
    public init(term: NSNumber? = nil, endDate: String? = nil, value: NSDecimalNumber? = nil,
                clearsValue: Bool = false, updatedAt: String? = nil) {
        self.term = term; self.endDate = endDate; self.value = value
        self.clearsValue = clearsValue; self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey { case term, value, endDate = "end_date", updatedAt = "updated_at" }

    public func encode(to encoder: Encoder) throws {
        let term = try contractInteger(term, name: "term", range: 1...Int.max)
        guard term != nil || endDate?.isBlank == false else {
            throw ValidationError("Contract renewal requires the current term or a new end date")
        }
        guard !clearsValue || value == nil else { throw ValidationError("Cannot set and clear value together") }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(term, forKey: .term)
        try c.encodeIfPresent(endDate, forKey: .endDate)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
        if clearsValue { try c.encodeNil(forKey: .value) }
        else { try c.encodeIfPresent(contractDecimal(value), forKey: .value) }
    }
}

/// Optional reason and concurrency precondition for terminating a contract.
@objcMembers
public final class TerminateContractPayload: NSObject, Encodable, @unchecked Sendable {
    /// Event reason, up to 500 characters; the server strips HTML.
    public let reason: String?
    /// Last-read timestamp; concurrent changes fail with `409`.
    public let updatedAt: String?

    /// Creates a termination request; both fields may be omitted.
    public init(reason: String? = nil, updatedAt: String? = nil) {
        self.reason = reason; self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey { case reason, updatedAt = "updated_at" }
}

private func contractInteger(_ number: NSNumber?, name: String, range: ClosedRange<Int>) throws -> Int? {
    guard let number else { return nil }
    let integer = number.intValue
    guard number.decimalValue == Decimal(integer), range.contains(integer) else {
        throw ValidationError("\(name) must be an integer in \(range.lowerBound)...\(range.upperBound)")
    }
    return integer
}

private func contractDecimal(_ number: NSDecimalNumber?) throws -> Decimal? {
    guard let number else { return nil }
    let decimal = number.decimalValue
    guard !decimal.isNaN else { throw ValidationError("Contract value must be a finite decimal") }
    return decimal
}
