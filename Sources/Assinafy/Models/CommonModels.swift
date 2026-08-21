import Foundation

// MARK: - PaginationMeta

/// Pagination metadata extracted from `X-Pagination-*` response headers.
@objcMembers
public final class PaginationMeta: NSObject {
    /// The current page number (1-indexed).
    public let currentPage: Int
    /// The last available page number.
    public let lastPage: Int
    /// The number of items per page.
    public let perPage: Int
    /// The total number of items across all pages.
    public let total: Int

    init(currentPage: Int, lastPage: Int, perPage: Int, total: Int) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.perPage = perPage
        self.total = total
    }
}

extension PaginationMeta: @unchecked Sendable {}

// MARK: - PaginatedResult

/// A page of results with optional pagination metadata.
///
/// `data` holds the items for the current page. `meta` is populated from
/// `X-Pagination-*` response headers and is `nil` when those headers are absent.
public struct PaginatedResult<T: Sendable>: Sendable {
    /// The items on the current page.
    public let data: [T]
    /// Pagination metadata, or `nil` when not provided by the server.
    public let meta: PaginationMeta?

    /// Creates a page of results.
    /// - Parameters:
    ///   - data: Items on the current page.
    ///   - meta: Optional pagination metadata from response headers.
    public init(data: [T], meta: PaginationMeta? = nil) {
        self.data = data
        self.meta = meta
    }
}

// MARK: - Logger

/// A simple logging protocol compatible with `OSLog`, `os_log`, and third-party loggers.
///
/// The SDK ships with a ``NoopLogger`` that silently discards all messages.
/// Provide your own conforming type to capture internal SDK events.
public protocol Logger: Sendable {
    /// Records a debug-level message with structured context.
    func debug(_ message: String, context: [String: Any])
    /// Records an informational message with structured context.
    func info(_ message: String, context: [String: Any])
    /// Records a warning message with structured context.
    func warn(_ message: String, context: [String: Any])
    /// Records an error message with structured context.
    func error(_ message: String, context: [String: Any])
}

public extension Logger {
    /// Records a debug-level message without additional context.
    func debug(_ message: String) { debug(message, context: [:]) }
    /// Records an informational message without additional context.
    func info(_ message: String)  { info(message, context: [:])  }
    /// Records a warning message without additional context.
    func warn(_ message: String)  { warn(message, context: [:])  }
    /// Records an error message without additional context.
    func error(_ message: String) { error(message, context: [:]) }
}

/// A logger that discards all messages. Used when no logger is configured.
public struct NoopLogger: Logger {
    /// Creates a logger that discards every message.
    public init() {}
    /// Discards a debug-level message and its context.
    public func debug(_ message: String, context: [String: Any]) {}
    /// Discards an informational message and its context.
    public func info(_ message: String, context: [String: Any])  {}
    /// Discards a warning message and its context.
    public func warn(_ message: String, context: [String: Any])  {}
    /// Discards an error message and its context.
    public func error(_ message: String, context: [String: Any]) {}
}

// MARK: - Internal helpers

struct AssinafyEnvelope<T: Decodable>: Decodable {
    let status: Int?
    let message: String?
    let data: T?
}

func decodeFlexibleString<K: CodingKey>(
    from container: KeyedDecodingContainer<K>,
    forKey key: K
) throws -> String {
    if let value = try? container.decode(String.self, forKey: key) {
        return value
    }
    if let value = try? container.decode(Int.self, forKey: key) {
        return String(value)
    }
    if let value = try? container.decode(Double.self, forKey: key) {
        return String(value)
    }
    if let value = try? container.decode(Bool.self, forKey: key) {
        return value ? "true" : "false"
    }
    return try container.decode(String.self, forKey: key)
}

func decodeFlexibleOptionalString<K: CodingKey>(
    from container: KeyedDecodingContainer<K>,
    forKey key: K
) throws -> String? {
    if (try? container.decodeNil(forKey: key)) == true {
        return nil
    }
    if let value = try? container.decode(String.self, forKey: key) {
        return value
    }
    if let value = try? container.decode(Int.self, forKey: key) {
        return String(value)
    }
    if let value = try? container.decode(Double.self, forKey: key) {
        return String(value)
    }
    if let value = try? container.decode(Bool.self, forKey: key) {
        return value ? "true" : "false"
    }
    if let raw = try? container.decode(JSONFragment.self, forKey: key) {
        return raw.stringValue
    }
    return nil
}

struct JSONFragment: Codable, Sendable, Equatable {
    enum Storage: Sendable, Equatable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case object([String: JSONFragment])
        case array([JSONFragment])
        case null
    }

    let storage: Storage

    init(_ storage: Storage) {
        self.storage = storage
    }

    init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            storage = .null
        } else if let value = try? single.decode(Bool.self) {
            storage = .bool(value)
        } else if let value = try? single.decode(Double.self) {
            storage = .number(value)
        } else if let value = try? single.decode(String.self) {
            storage = .string(value)
        } else if let value = try? single.decode([String: JSONFragment].self) {
            storage = .object(value)
        } else if let value = try? single.decode([JSONFragment].self) {
            storage = .array(value)
        } else {
            storage = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        switch storage {
        case .string(let value): try single.encode(value)
        case .number(let value): try single.encode(value)
        case .bool(let value): try single.encode(value)
        case .object(let value): try single.encode(value)
        case .array(let value): try single.encode(value)
        case .null: try single.encodeNil()
        }
    }

    var stringValue: String {
        switch storage {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object, .array:
            let data = try? JSONEncoder.assinafy.encode(self)
            return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        case .null:
            return ""
        }
    }
}

extension String {
    var utf8Data: Data { Data(self.utf8) }
}

func parsePaginationMeta(from headers: [AnyHashable: Any]) -> PaginationMeta? {
    func int(_ key: String) -> Int? {
        guard let value = headers.first(where: {
            String(describing: $0.key).caseInsensitiveCompare(key) == .orderedSame
        })?.value else { return nil }
        if let number = value as? NSNumber { return number.intValue }
        return Int(String(describing: value))
    }
    let cp = int("X-Pagination-Current-Page")
    let pp = int("X-Pagination-Per-Page")
    let tc = int("X-Pagination-Total-Count")
    let lp = int("X-Pagination-Page-Count")
    guard cp != nil || pp != nil || tc != nil || lp != nil else { return nil }
    return PaginationMeta(
        currentPage: cp ?? 0,
        lastPage: lp ?? 0,
        perPage: pp ?? 0,
        total: tc ?? 0
    )
}

// MARK: - ListParams

/// Query parameters for paginated list endpoints.
public struct ListParams: Sendable {
    public var page: Int?
    public var perPage: Int?
    public var search: String?
    public var sort: String?
    public var extra: [String: String]

    /// Creates pagination, search, sorting, and endpoint-specific query options.
    /// - Parameters:
    ///   - page: One-based page number.
    ///   - perPage: Maximum items per page.
    ///   - search: Optional free-text search term.
    ///   - sort: Optional API sort expression.
    ///   - extra: Additional endpoint-specific query parameters.
    public init(
        page: Int? = nil,
        perPage: Int? = nil,
        search: String? = nil,
        sort: String? = nil,
        extra: [String: String] = [:]
    ) {
        self.page = page
        self.perPage = perPage
        self.search = search
        self.sort = sort
        self.extra = extra
    }

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let p = page, p > 0     { items.append(.init(name: "page",     value: "\(p)")) }
        if let p = perPage, p > 0  { items.append(.init(name: "per-page", value: "\(p)")) }
        if let s = search, !s.isEmpty { items.append(.init(name: "search", value: s)) }
        if let s = sort, !s.isEmpty   { items.append(.init(name: "sort", value: s)) }
        for (k, v) in extra.sorted(by: { $0.key < $1.key }) {
            items.append(.init(name: k, value: v))
        }
        return items
    }
}
