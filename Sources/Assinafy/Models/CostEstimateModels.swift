import Foundation

/// One line item in an Assinafy cost estimate.
@objcMembers
public final class CostEstimateBreakdownItem: NSObject {
    /// Machine-readable charge code, such as `NotificationWhatsapp`.
    public let code: String
    /// Human-readable charge name.
    public let name: String
    /// Total cost for this line item.
    public let cost: Double
    /// Number of units charged.
    public let quantity: Int
    /// Cost of one unit.
    public let unitCost: Double

    init(code: String, name: String, cost: Double, quantity: Int, unitCost: Double) {
        self.code = code
        self.name = name
        self.cost = cost
        self.quantity = quantity
        self.unitCost = unitCost
    }

    fileprivate convenience init(raw: [String: Any]) throws {
        self.init(
            code: try CostEstimate.string(raw, "code") ?? "",
            name: try CostEstimate.string(raw, "name") ?? "",
            cost: try CostEstimate.double(raw, "cost"),
            quantity: try CostEstimate.integer(raw, "quantity"),
            unitCost: try CostEstimate.double(raw, "unit_cost")
        )
    }
}

extension CostEstimateBreakdownItem: @unchecked Sendable {}

/// Cost estimate returned by the Assinafy assignment and template endpoints.
///
/// The documented fields are exposed as typed properties. ``raw`` remains
/// available for source compatibility and forwards-compatible inspection.
@objcMembers
public final class CostEstimate: NSObject, Decodable {
    /// The current credit balance available on the account.
    public let creditBalance: Double
    /// The current document balance available on the account.
    public let documentBalance: Double
    /// The estimated cost in credits required to complete the operation.
    public let estimatedCost: Double
    /// Whether the account has enough balance to cover ``estimatedCost``.
    public let hasSufficientBalance: Bool
    /// Number of documents this operation will consume.
    public let documents: Double
    /// Integer document count from the current API schema.
    public var documentCount: Int { Self.safeInteger(documents) ?? 0 }
    /// Credit cost for notifications or extra usage.
    public let credits: Double
    /// Whether the operation requires an extra document charge.
    public let needsExtraDocument: Bool
    /// Cost of the extra document, when required.
    public let extraDocumentCost: Double
    /// Total credits required by the operation.
    public let totalCredits: Double
    /// Itemized notification and extra-document charges.
    public let breakdown: [CostEstimateBreakdownItem]
    /// Canonical API flag indicating whether the account has sufficient documents/credits.
    public let hasSufficientResources: Bool
    /// Blocking reason returned by the API, when the operation cannot proceed.
    public let blockingReason: String?
    /// Human-readable cost or blocking message returned by the API.
    public let message: String?
    /// All raw fields returned by the server, including any that aren't
    /// surfaced as typed properties.
    public let raw: [String: Any]

    init(creditBalance: Double, documentBalance: Double, estimatedCost: Double,
         hasSufficientBalance: Bool, documents: Double, credits: Double,
         needsExtraDocument: Bool, extraDocumentCost: Double, totalCredits: Double,
         breakdown: [CostEstimateBreakdownItem], hasSufficientResources: Bool,
         blockingReason: String?, message: String?,
         raw: [String: Any]) {
        self.creditBalance = creditBalance
        self.documentBalance = documentBalance
        self.estimatedCost = estimatedCost
        self.hasSufficientBalance = hasSufficientBalance
        self.documents = documents
        self.credits = credits
        self.needsExtraDocument = needsExtraDocument
        self.extraDocumentCost = extraDocumentCost
        self.totalCredits = totalCredits
        self.breakdown = breakdown
        self.hasSufficientResources = hasSufficientResources
        self.blockingReason = blockingReason
        self.message = message
        self.raw = raw
    }

    private convenience init(raw: [String: Any]) throws {
        let totalCredits = try Self.double(raw, "total_credits")
        let credits = try Self.double(raw, "credits")
        let estimated = try Self.double(raw, "estimated_cost")
        let legacyTotal = try Self.double(raw, "total")
        let hasResources = try Self.bool(raw, "has_sufficient_resources")
            ?? Self.bool(raw, "has_sufficient_balance")
            ?? false
        let breakdownValues: [[String: Any]]
        if let value = raw["breakdown"], !(value is NSNull) {
            guard let value = value as? [[String: Any]] else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "breakdown must be an array of objects")
                )
            }
            breakdownValues = value
        } else {
            breakdownValues = []
        }
        let breakdown = try breakdownValues.map {
            try CostEstimateBreakdownItem(raw: $0)
        }
        let resolvedEstimate: Double
        if raw["estimated_cost"] != nil {
            resolvedEstimate = estimated
        } else if raw["total_credits"] != nil {
            resolvedEstimate = totalCredits
        } else if raw["total"] != nil {
            resolvedEstimate = legacyTotal
        } else {
            resolvedEstimate = credits
        }
        self.init(
            creditBalance:        try Self.double(raw, "credit_balance"),
            documentBalance:      try Self.double(raw, "document_balance"),
            estimatedCost:        resolvedEstimate,
            hasSufficientBalance: hasResources,
            documents:            Double(try Self.integer(raw, "documents")),
            credits:              credits,
            needsExtraDocument:   try Self.bool(raw, "needs_extra_document") ?? false,
            extraDocumentCost:    try Self.double(raw, "extra_document_cost"),
            totalCredits:         totalCredits,
            breakdown:            breakdown,
            hasSufficientResources: hasResources,
            blockingReason:       try Self.string(raw, "blocking_reason"),
            message:              try Self.string(raw, "message"),
            raw: raw
        )
    }

    public convenience init(from decoder: Decoder) throws {
        let fragment = try JSONFragment(from: decoder)
        guard case .object(let values) = fragment.storage else {
            throw DecodingError.typeMismatch(
                [String: JSONFragment].self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected a cost-estimate object")
            )
        }
        guard values["status"] == nil, values["data"] == nil else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Expected estimate data, not a response envelope")
            )
        }
        let knownKeys: Set<String> = [
            "documents", "credits", "needs_extra_document", "extra_document_cost",
            "total_credits", "breakdown", "document_balance", "credit_balance",
            "has_sufficient_resources", "blocking_reason", "message",
            // Compatibility keys returned by earlier estimate endpoints.
            "estimated_cost", "has_sufficient_balance", "total",
        ]
        guard values.keys.contains(where: knownKeys.contains) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Cost estimate contains no recognized fields")
            )
        }
        try self.init(raw: values.mapValues(\.foundationValue))
    }

    fileprivate static func double(_ dict: [String: Any], _ key: String) throws -> Double {
        guard let raw = dict[key], !(raw is NSNull) else { return 0 }
        let value: Double?
        switch raw {
        case is Bool: value = nil
        case let number as Double: value = number
        case let number as Int: value = Double(number)
        case let number as Int64: value = Double(number)
        case let number as UInt64: value = Double(number)
        case let number as NSNumber: value = number.doubleValue
        case let string as String: value = Double(string)
        default: value = nil
        }
        guard let value, value.isFinite else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "\(key) must be a finite number")
            )
        }
        return value
    }

    fileprivate static func integer(_ dict: [String: Any], _ key: String) throws -> Int {
        let value = try double(dict, key)
        guard let integer = safeInteger(value) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "\(key) must be a finite integer")
            )
        }
        return integer
    }

    fileprivate static func bool(_ dict: [String: Any], _ key: String) throws -> Bool? {
        guard let value = dict[key], !(value is NSNull) else { return nil }
        guard let value = value as? Bool else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "\(key) must be a boolean")
            )
        }
        return value
    }

    fileprivate static func string(_ dict: [String: Any], _ key: String) throws -> String? {
        guard let value = dict[key], !(value is NSNull) else { return nil }
        guard let value = value as? String else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "\(key) must be a string")
            )
        }
        return value
    }

    fileprivate static func safeInteger(_ value: Double) -> Int? {
        guard value.isFinite,
              value.rounded(.towardZero) == value,
              value >= Double(Int.min),
              value < Double(Int.max) else { return nil }
        return Int(value)
    }

}

extension CostEstimate: @unchecked Sendable {}
