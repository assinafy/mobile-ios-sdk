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
    func debug(_ message: String, context: [String: Any])
    func info(_ message: String, context: [String: Any])
    func warn(_ message: String, context: [String: Any])
    func error(_ message: String, context: [String: Any])
}

public extension Logger {
    func debug(_ message: String) { debug(message, context: [:]) }
    func info(_ message: String)  { info(message, context: [:])  }
    func warn(_ message: String)  { warn(message, context: [:])  }
    func error(_ message: String) { error(message, context: [:]) }
}

/// A logger that discards all messages. Used when no logger is configured.
public struct NoopLogger: Logger {
    public init() {}
    public func debug(_ message: String, context: [String: Any]) {}
    public func info(_ message: String, context: [String: Any])  {}
    public func warn(_ message: String, context: [String: Any])  {}
    public func error(_ message: String, context: [String: Any]) {}
}

// MARK: - Internal helpers

struct AssinafyEnvelope<T: Decodable>: Decodable {
    let status: Int?
    let message: String?
    let data: T?
}

extension String {
    var utf8Data: Data { Data(self.utf8) }
}

func parsePaginationMeta(from headers: [AnyHashable: Any]) -> PaginationMeta? {
    func int(_ key: String) -> Int? {
        let v = headers[key] ?? headers[key.lowercased()]
        guard let s = v as? String, let n = Int(s) else { return nil }
        return n
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
        if let p = page     { items.append(.init(name: "page",     value: "\(p)")) }
        if let p = perPage  { items.append(.init(name: "per-page", value: "\(p)")) }
        if let s = search   { items.append(.init(name: "search",   value: s))     }
        if let s = sort     { items.append(.init(name: "sort",     value: s))     }
        for (k, v) in extra { items.append(.init(name: k, value: v)) }
        return items
    }
}
