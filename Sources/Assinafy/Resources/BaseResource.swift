import Foundation

/// Abstract base class shared by all Assinafy resource objects.
///
/// Provides:
/// - ``accountId(_:)`` / ``requireId(_:name:)`` argument guards
/// - Type-safe HTTP helpers (`call`, `callVoid`, `callData`, `callList`)
/// - Automatic API response-envelope unwrapping
/// - Pagination metadata extraction from `X-Pagination-*` headers
///
/// Do not instantiate this class directly; use its concrete subclasses via ``AssinafyClient``.
open class BaseResource: NSObject {
    let http: HTTPClientProtocol
    let defaultAccountId: String?
    let logger: Logger

    init(http: HTTPClientProtocol, defaultAccountId: String? = nil, logger: Logger = NoopLogger()) {
        self.http = http
        self.defaultAccountId = defaultAccountId
        self.logger = logger
    }

    /// Resolves the effective account ID, throwing ``ValidationError`` when none is available.
    func accountId(_ explicit: String? = nil) throws -> String {
        guard let id = explicit ?? defaultAccountId, !id.isEmpty else {
            throw ValidationError(
                "Account ID is required. Provide it as a parameter or set a default in the client."
            )
        }
        return id
    }

    /// Guards a required path parameter, throwing ``ValidationError`` when blank.
    func requireId(_ value: String?, name: String) throws -> String {
        guard let value, !value.isEmpty else {
            throw ValidationError("\(name) is required")
        }
        return value
    }

    // MARK: HTTP helpers

    func call<T: Decodable>(_ label: String, request: APIRequest) async throws -> T {
        do {
            let response = try await http.perform(request)
            return try unwrapEnvelope(response.data, label: label)
        } catch let error as AssinafyErrorProtocol {
            throw error
        } catch {
            throw toSDKError(error, fallback: label)
        }
    }

    func callVoid(_ label: String, request: APIRequest) async throws {
        do {
            _ = try await http.perform(request)
        } catch let error as AssinafyErrorProtocol {
            throw error
        } catch {
            throw toSDKError(error, fallback: label)
        }
    }

    func callData(_ label: String, request: APIRequest) async throws -> Data {
        do {
            let response = try await http.perform(request)
            return response.data
        } catch let error as AssinafyErrorProtocol {
            throw error
        } catch {
            throw toSDKError(error, fallback: label)
        }
    }

    func callList<T: Decodable>(_ label: String, request: APIRequest) async throws -> PaginatedResult<T> {
        do {
            let response = try await http.perform(request)
            let data: [T] = try unwrapListEnvelope(response.data, label: label)
            let meta = parsePaginationMeta(from: response.headers)
            return PaginatedResult(data: data, meta: meta)
        } catch let error as AssinafyErrorProtocol {
            throw error
        } catch {
            throw toSDKError(error, fallback: label)
        }
    }

    func callCostEstimate(_ label: String, request: APIRequest) async throws -> CostEstimate {
        do {
            let response = try await http.perform(request)
            let raw = (try? JSONSerialization.jsonObject(with: response.data)) as? [String: Any]
            let data = (raw?["data"] as? [String: Any]) ?? raw ?? [:]
            return CostEstimate.from(data)
        } catch let error as AssinafyErrorProtocol {
            throw error
        } catch {
            throw toSDKError(error, fallback: label)
        }
    }

    // MARK: Completion-handler bridge

    /// Wraps an `async throws` block in a `Task` and delivers the result
    /// to `completion` on the **main queue** — safe for UI updates.
    func withCompletion<T>(
        _ block: @escaping () async throws -> T,
        completion: @escaping (T?, Error?) -> Void
    ) {
        Task {
            do {
                let value = try await block()
                DispatchQueue.main.async { completion(value, nil) }
            } catch {
                DispatchQueue.main.async { completion(nil, error) }
            }
        }
    }

    func withVoidCompletion(
        _ block: @escaping () async throws -> Void,
        completion: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                try await block()
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    /// Bridges a paginated `async` call to a completion handler that receives
    /// only the items array — convenient for Objective-C consumers.
    func withListCompletion<T>(
        _ block: @escaping () async throws -> PaginatedResult<T>,
        completion: @escaping ([T]?, Error?) -> Void
    ) {
        withCompletion({ try await block().data }, completion: completion)
    }

    /// Like ``withCompletion(_:completion:)`` but for blocks that return an
    /// already-optional value, avoiding double-optional wrapping.
    func withOptionalCompletion<T>(
        _ block: @escaping () async throws -> T?,
        completion: @escaping (T?, Error?) -> Void
    ) {
        Task {
            do {
                let value = try await block()
                DispatchQueue.main.async { completion(value, nil) }
            } catch {
                DispatchQueue.main.async { completion(nil, error) }
            }
        }
    }

    // MARK: Private envelope helpers

    private func unwrapEnvelope<T: Decodable>(_ data: Data, label: String) throws -> T {
        if let envelope = try? JSONDecoder.assinafy.decode(AssinafyEnvelope<T>.self, from: data) {
            if let status = envelope.status {
                if status >= 200 && status < 300 {
                    if let value = envelope.data { return value }
                    throw ValidationError("\(label): response envelope contained no data")
                }
                let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                throw APIError.from(statusCode: status, responseData: raw)
            }
            if let value = envelope.data { return value }
        }
        return try JSONDecoder.assinafy.decode(T.self, from: data)
    }

    private func unwrapListEnvelope<T: Decodable>(_ data: Data, label: String) throws -> [T] {
        if let envelope = try? JSONDecoder.assinafy.decode(AssinafyEnvelope<[T]>.self, from: data) {
            if let status = envelope.status, status >= 200, status < 300 { return envelope.data ?? [] }
            if let arr = envelope.data { return arr }
        }
        return (try? JSONDecoder.assinafy.decode([T].self, from: data)) ?? []
    }
}

private func toSDKError(_ error: Error, fallback: String) -> Error {
    if let urlError = error as? URLError {
        return NetworkError("\(fallback): \(urlError.localizedDescription)", underlyingError: urlError)
    }
    return AssinafySDKError("\(fallback): \(error.localizedDescription)", underlyingError: error)
}
