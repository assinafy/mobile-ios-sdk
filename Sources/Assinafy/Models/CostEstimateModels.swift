import Foundation

/// Cost breakdown returned by the Assinafy estimate endpoints.
///
/// The Assinafy API returns variable cost-breakdown fields depending on the
/// endpoint and account plan. This model exposes the common documented fields
/// and preserves all server-returned values in ``raw`` for forwards
/// compatibility.
@objcMembers
public final class CostEstimate: NSObject {
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
         hasSufficientResources: Bool, blockingReason: String?, message: String?,
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
        self.hasSufficientResources = hasSufficientResources
        self.blockingReason = blockingReason
        self.message = message
        self.raw = raw
    }

    static func from(_ raw: [String: Any]) -> CostEstimate {
        let totalCredits = Self.double(raw, "total_credits")
        let credits = Self.double(raw, "credits")
        let estimated = Self.double(raw, "estimated_cost")
        let hasResources = (raw["has_sufficient_resources"] as? Bool)
            ?? (raw["has_sufficient_balance"] as? Bool)
            ?? false
        return CostEstimate(
            creditBalance:        Self.double(raw, "credit_balance"),
            documentBalance:      Self.double(raw, "document_balance"),
            estimatedCost:        estimated != 0 ? estimated : (totalCredits != 0 ? totalCredits : credits),
            hasSufficientBalance: hasResources,
            documents:            Self.double(raw, "documents"),
            credits:              credits,
            needsExtraDocument:   (raw["needs_extra_document"] as? Bool) ?? false,
            extraDocumentCost:    Self.double(raw, "extra_document_cost"),
            totalCredits:         totalCredits,
            hasSufficientResources: hasResources,
            blockingReason:       raw["blocking_reason"] as? String,
            message:              raw["message"] as? String,
            raw: raw
        )
    }

    private static func double(_ dict: [String: Any], _ key: String) -> Double {
        if let n = dict[key] as? Double { return n }
        if let n = dict[key] as? Int    { return Double(n) }
        if let s = dict[key] as? String { return Double(s) ?? 0 }
        return 0
    }
}

extension CostEstimate: @unchecked Sendable {}
