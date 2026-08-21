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

    fileprivate convenience init(raw: [String: Any]) {
        self.init(
            code: raw["code"] as? String ?? "",
            name: raw["name"] as? String ?? "",
            cost: CostEstimate.double(raw, "cost"),
            quantity: Int(CostEstimate.double(raw, "quantity")),
            unitCost: CostEstimate.double(raw, "unit_cost")
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

    private convenience init(raw: [String: Any]) {
        let totalCredits = Self.double(raw, "total_credits")
        let credits = Self.double(raw, "credits")
        let estimated = Self.double(raw, "estimated_cost")
        let legacyTotal = Self.double(raw, "total")
        let hasResources = (raw["has_sufficient_resources"] as? Bool)
            ?? (raw["has_sufficient_balance"] as? Bool)
            ?? false
        let breakdown = (raw["breakdown"] as? [[String: Any]] ?? []).map {
            CostEstimateBreakdownItem(raw: $0)
        }
        self.init(
            creditBalance:        Self.double(raw, "credit_balance"),
            documentBalance:      Self.double(raw, "document_balance"),
            estimatedCost:        estimated != 0
                ? estimated
                : (totalCredits != 0 ? totalCredits : (legacyTotal != 0 ? legacyTotal : credits)),
            hasSufficientBalance: hasResources,
            documents:            Self.double(raw, "documents"),
            credits:              credits,
            needsExtraDocument:   (raw["needs_extra_document"] as? Bool) ?? false,
            extraDocumentCost:    Self.double(raw, "extra_document_cost"),
            totalCredits:         totalCredits,
            breakdown:            breakdown,
            hasSufficientResources: hasResources,
            blockingReason:       raw["blocking_reason"] as? String,
            message:              raw["message"] as? String,
            raw: raw
        )
    }

    static func from(_ raw: [String: Any]) -> CostEstimate {
        CostEstimate(raw: raw)
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
        self.init(raw: values.mapValues(Self.anyValue))
    }

    fileprivate static func double(_ dict: [String: Any], _ key: String) -> Double {
        if let n = dict[key] as? Double { return n }
        if let n = dict[key] as? Int    { return Double(n) }
        if let n = dict[key] as? NSNumber { return n.doubleValue }
        if let s = dict[key] as? String { return Double(s) ?? 0 }
        return 0
    }

    private static func anyValue(_ fragment: JSONFragment) -> Any {
        switch fragment.storage {
        case .string(let value): return value
        case .number(let value): return value
        case .bool(let value): return value
        case .object(let value): return value.mapValues(anyValue)
        case .array(let value): return value.map(anyValue)
        case .null: return NSNull()
        }
    }
}

extension CostEstimate: @unchecked Sendable {}
