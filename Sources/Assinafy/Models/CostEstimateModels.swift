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
    /// All raw fields returned by the server, including any that aren't
    /// surfaced as typed properties.
    public let raw: [String: Any]

    init(creditBalance: Double, documentBalance: Double, estimatedCost: Double,
         hasSufficientBalance: Bool, raw: [String: Any]) {
        self.creditBalance = creditBalance
        self.documentBalance = documentBalance
        self.estimatedCost = estimatedCost
        self.hasSufficientBalance = hasSufficientBalance
        self.raw = raw
    }

    static func from(_ raw: [String: Any]) -> CostEstimate {
        CostEstimate(
            creditBalance:        Self.double(raw, "credit_balance"),
            documentBalance:      Self.double(raw, "document_balance"),
            estimatedCost:        Self.double(raw, "estimated_cost"),
            hasSufficientBalance: (raw["has_sufficient_balance"] as? Bool) ?? false,
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
