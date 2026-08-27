import Foundation

/// Abstract base class shared by all Assinafy resource objects.
///
/// Provides:
/// - `accountId(_:)` / `requireId(_:name:)` argument guards
/// - Type-safe HTTP helpers (`call`, `callVoid`, `callData`, `callList`)
/// - Automatic API response-envelope unwrapping
/// - Pagination metadata extraction from `X-Pagination-*` headers
///
/// Do not instantiate this class directly; use its concrete subclasses via ``AssinafyClient``.
open class BaseResource: NSObject {
    let http: HTTPClientProtocol
    let defaultAccountId: String?
    let logger: Logger
    let usesSandboxCompatibility: Bool

    init(
        http: HTTPClientProtocol,
        defaultAccountId: String? = nil,
        logger: Logger = NoopLogger(),
        usesSandboxCompatibility: Bool = false
    ) {
        self.http = http
        self.defaultAccountId = defaultAccountId
        self.logger = logger
        self.usesSandboxCompatibility = usesSandboxCompatibility
    }

    /// Resolves the effective account ID, throwing ``ValidationError`` when none is available.
    func accountId(_ explicit: String? = nil) throws -> String {
        guard let id = explicit ?? defaultAccountId else {
            throw ValidationError(
                "Account ID is required. Provide it as a parameter or set a default in the client."
            )
        }
        return try requireId(id, name: "Account ID")
    }

    /// Guards a required path parameter, throwing ``ValidationError`` when blank.
    func requireId(_ value: String?, name: String) throws -> String {
        guard let value else {
            throw ValidationError("\(name) is required")
        }
        return try AssinafyClientConfiguration.validateIdentifier(value, name: name)
    }

    // MARK: HTTP helpers

    func call<T: Decodable & Sendable>(_ label: String, request: APIRequest) async throws -> T {
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
            let response = try await http.perform(request)
            try validateVoidEnvelope(response.data)
        } catch let error as AssinafyErrorProtocol {
            throw error
        } catch {
            throw toSDKError(error, fallback: label)
        }
    }

    func callData(_ label: String, request: APIRequest) async throws -> Data {
        do {
            let response = try await http.perform(request)
            if let error = embeddedAPIError(in: response.data) { throw error }
            return response.data
        } catch let error as AssinafyErrorProtocol {
            throw error
        } catch {
            throw toSDKError(error, fallback: label)
        }
    }

    func callList<T: Decodable & Sendable>(_ label: String, request: APIRequest) async throws -> PaginatedResult<T> {
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

    // MARK: Completion-handler bridge

    /// Wraps an `async throws` block in a `Task` and delivers the result
    /// to `completion` on the **main queue** — safe for UI updates.
    func withCompletion<T>(
        _ block: @escaping () async throws -> T,
        completion: @escaping (T?, Error?) -> Void
    ) {
        let work = UncheckedSendable(block)
        let callback = UncheckedSendable(completion)
        Task { [work, callback] in
            let result: Result<T, Error>
            do {
                result = .success(try await work.value())
            } catch {
                result = .failure(error)
            }
            let delivery = UncheckedSendable(result)
            DispatchQueue.main.async { [callback, delivery] in
                switch delivery.value {
                case .success(let value): callback.value(value, nil)
                case .failure(let error): callback.value(nil, error)
                }
            }
        }
    }

    func withVoidCompletion(
        _ block: @escaping () async throws -> Void,
        completion: @escaping (Error?) -> Void
    ) {
        let work = UncheckedSendable(block)
        let callback = UncheckedSendable(completion)
        Task { [work, callback] in
            let error: Error?
            do {
                try await work.value()
                error = nil
            } catch let caught {
                error = caught
            }
            let delivery = UncheckedSendable(error)
            DispatchQueue.main.async { [callback, delivery] in
                callback.value(delivery.value)
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
        let work = UncheckedSendable(block)
        let callback = UncheckedSendable(completion)
        Task { [work, callback] in
            let result: Result<T?, Error>
            do {
                result = .success(try await work.value())
            } catch {
                result = .failure(error)
            }
            let delivery = UncheckedSendable(result)
            DispatchQueue.main.async { [callback, delivery] in
                switch delivery.value {
                case .success(let value): callback.value(value, nil)
                case .failure(let error): callback.value(nil, error)
                }
            }
        }
    }

    // MARK: Private envelope helpers

    private func unwrapEnvelope<T: Decodable>(_ data: Data, label: String) throws -> T {
        if let error = embeddedAPIError(in: data) { throw error }
        if let envelope = try? JSONDecoder.assinafy.decode(AssinafyEnvelope<T>.self, from: data) {
            if let status = envelope.status {
                if status >= 200 && status < 300 {
                    if let value = envelope.data { return value }
                    throw AssinafySDKError("\(label): response envelope contained no data")
                }
                let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                throw APIError.from(statusCode: status, responseData: raw)
            }
            if let value = envelope.data { return value }
        }
        return try JSONDecoder.assinafy.decode(T.self, from: data)
    }

    private func unwrapListEnvelope<T: Decodable>(_ data: Data, label: String) throws -> [T] {
        if let error = embeddedAPIError(in: data) { throw error }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["data"] != nil || object["status"] != nil || object["message"] != nil {
            let envelope = try JSONDecoder.assinafy.decode(AssinafyEnvelope<[T]>.self, from: data)
            guard let values = envelope.data else {
                throw AssinafySDKError("\(label): response envelope contained no data")
            }
            return values
        }
        return try JSONDecoder.assinafy.decode([T].self, from: data)
    }

    private func validateVoidEnvelope(_ data: Data) throws {
        if let error = embeddedAPIError(in: data) { throw error }
    }
}

extension BaseResource: @unchecked Sendable {}

/// Explicitly carries callback-style values across Swift concurrency boundaries.
/// Objective-C completion handlers cannot express `Sendable`, so the bridge
/// confines their use to a `Task` and delivery on the main queue.
private struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

private func toSDKError(_ error: Error, fallback: String) -> Error {
    if error is CancellationError { return error }
    if let urlError = error as? URLError {
        return NetworkError("\(fallback): \(urlError.localizedDescription)", underlyingError: urlError)
    }
    return AssinafySDKError("\(fallback): \(error.localizedDescription)", underlyingError: error)
}

private func embeddedAPIError(in data: Data) -> APIError? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let status = object["status"] as? Int,
          !(200..<300).contains(status) else { return nil }
    return APIError.from(statusCode: status, responseData: object)
}
