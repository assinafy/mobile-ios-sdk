import Foundation

// MARK: - Protocol

/// Base protocol adopted by every error type the SDK may throw.
///
/// Conforming types carry a human-readable ``message`` and a structured
/// ``context`` dictionary for logging and debugging.
public protocol AssinafyErrorProtocol: Error {
    /// A human-readable description of the error.
    var message: String { get }
    /// Structured context information useful for logging.
    var context: [String: Any] { get }
}

// MARK: - Error Domains

/// Error domains used when Swift SDK errors bridge to Objective-C `NSError`.
///
/// `NSError.code` contains the HTTP status for API errors, `422` for local
/// validation, the underlying `URLError.Code` for network failures, or `-1`
/// for SDK contract errors. Details are available in `userInfo` under
/// `responseData`, `errors`, and `NSUnderlyingErrorKey` as applicable.
@objc public final class ASFErrorDomain: NSObject {
    @objc public static let api        = "com.assinafy.sdk.APIError"
    @objc public static let validation = "com.assinafy.sdk.ValidationError"
    @objc public static let network    = "com.assinafy.sdk.NetworkError"
    @objc public static let sdk        = "com.assinafy.sdk.SDKError"
}

// MARK: - AssinafySDKError

/// A generic SDK-level error for unexpected conditions not covered by
/// ``APIError``, ``ValidationError``, or ``NetworkError``.
public struct AssinafySDKError: AssinafyErrorProtocol, LocalizedError {
    public let message: String
    public let context: [String: Any]
    public let underlyingError: Error?

    /// Creates an SDK error with optional diagnostic context and underlying cause.
    public init(_ message: String, context: [String: Any] = [:], underlyingError: Error? = nil) {
        self.message = message
        self.context = context
        self.underlyingError = underlyingError
    }

    public var errorDescription: String? { message }
}

extension AssinafySDKError: @unchecked Sendable {}

extension AssinafySDKError: CustomNSError {
    public static var errorDomain: String { ASFErrorDomain.sdk }
    public var errorCode: Int { -1 }
    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [NSLocalizedDescriptionKey: message]
        info.merge(context) { _, new in new }
        if let cause = underlyingError { info[NSUnderlyingErrorKey] = cause as NSError }
        return info
    }
}

// MARK: - APIError

/// Thrown when the Assinafy API returns a non-success HTTP status code.
///
/// Inspect ``statusCode`` to determine the specific failure and
/// ``responseData`` for the raw response body.
public struct APIError: AssinafyErrorProtocol, LocalizedError {
    /// The HTTP status code returned by the server.
    public let statusCode: Int
    /// The error message extracted from the API response envelope.
    public let message: String
    /// The raw response data, if available.
    public let responseData: Any?

    public var context: [String: Any] {
        ["statusCode": statusCode, "responseData": responseData as Any]
    }

    /// Typed blockers returned by a failed workspace deletion request.
    ///
    /// The array is empty for other API errors or when the server does not
    /// include a valid `restrictions` payload.
    public var workspaceDeletionRestrictions: [WorkspaceDeletionRestriction] {
        guard let object = responseData as? [String: Any],
              let values = object["restrictions"] as? [[String: Any]] else {
            return []
        }
        return values.compactMap { value in
            guard let code = value["code"] as? String,
                  let message = value["message"] as? String else { return nil }
            return WorkspaceDeletionRestriction(
                code: code,
                message: message,
                accountIds: value["account_ids"] as? [String] ?? []
            )
        }
    }

    /// Creates an API error from an HTTP status, message, and optional response payload.
    public init(statusCode: Int, message: String, responseData: Any? = nil) {
        self.statusCode = statusCode
        self.message = message
        self.responseData = responseData
    }

    /// Construct an ``APIError`` from a raw HTTP status code and response body.
    static func from(statusCode: Int, responseData: Any?) -> APIError {
        let msg: String
        if let data = responseData as? [String: Any],
           let value = (data["message"] as? String) ?? (data["error"] as? String),
           !value.isEmpty {
            msg = value
        } else if let value = responseData as? String, !value.isEmpty {
            msg = value
        } else {
            msg = "API request failed"
        }
        return APIError(statusCode: statusCode, message: msg, responseData: responseData)
    }

    public var errorDescription: String? { message }
}

extension APIError: @unchecked Sendable {}

extension APIError: CustomNSError {
    public static var errorDomain: String { ASFErrorDomain.api }
    public var errorCode: Int { statusCode }
    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [NSLocalizedDescriptionKey: message]
        if let data = responseData { info["responseData"] = data }
        return info
    }
}

// MARK: - ValidationError

/// Thrown when client-side validation fails before a network request is sent.
///
/// ``errors`` carries field-level details that can be surfaced to users.
public struct ValidationError: AssinafyErrorProtocol, LocalizedError {
    public let message: String
    /// Field-level validation errors, keyed by field name.
    public let errors: [String: Any]
    public var context: [String: Any] { ["errors": errors] }

    /// Creates a validation error with optional field-level details.
    public init(_ message: String = "Validation failed", errors: [String: Any] = [:]) {
        self.message = message
        self.errors = errors
    }

    public var errorDescription: String? { message }
}

extension ValidationError: @unchecked Sendable {}

extension ValidationError: CustomNSError {
    public static var errorDomain: String { ASFErrorDomain.validation }
    public var errorCode: Int { 422 }
    public var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: message, "errors": errors]
    }
}

// MARK: - NetworkError

/// Thrown when the network transport fails (DNS resolution, timeout, SSL, etc.)
/// before a response is received from the server.
public struct NetworkError: AssinafyErrorProtocol, LocalizedError {
    public let message: String
    public let underlyingError: Error?
    public var context: [String: Any] { [:] }

    /// Creates a transport error with an optional underlying system error.
    public init(_ message: String, underlyingError: Error? = nil) {
        self.message = message
        self.underlyingError = underlyingError
    }

    public var errorDescription: String? { message }
}

extension NetworkError: @unchecked Sendable {}

extension NetworkError: CustomNSError {
    public static var errorDomain: String { ASFErrorDomain.network }
    public var errorCode: Int {
        (underlyingError as? URLError)?.errorCode ?? URLError.notConnectedToInternet.rawValue
    }
    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [NSLocalizedDescriptionKey: message]
        if let cause = underlyingError { info[NSUnderlyingErrorKey] = cause as NSError }
        return info
    }
}
