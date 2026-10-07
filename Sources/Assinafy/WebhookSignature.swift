import CryptoKit
import Foundation

/// Verifies the Standard Webhooks signature Assinafy adds to deliveries for
/// endpoints with signing enabled.
///
/// Use it on the server that receives webhooks. Pass the **raw** request body,
/// exactly as received — re-serialized JSON will not verify.
///
/// ```swift
/// let valid = WebhookSignature.verify(
///     body: rawBody,
///     id: headers["webhook-id"] ?? "",
///     timestamp: headers["webhook-timestamp"] ?? "",
///     signatureHeader: headers["webhook-signature"] ?? "",
///     secret: endpointSecret
/// )
/// ```
@objcMembers
public final class WebhookSignature: NSObject {

    /// Default accepted distance between `webhook-timestamp` and the local clock, in seconds.
    public static let defaultTolerance: TimeInterval = 300

    /// Returns `true` when any `v1,` entry of `signatureHeader` is the HMAC-SHA256 of
    /// `{id}.{timestamp}.{body}` under `secret`, and `timestamp` is within `tolerance`
    /// of `now`. The comparison is constant-time.
    ///
    /// - Parameters:
    ///   - body: The raw request body.
    ///   - id: The `webhook-id` header.
    ///   - timestamp: The `webhook-timestamp` header (Unix seconds).
    ///   - signatureHeader: The `webhook-signature` header: space-separated `v1,<base64>` entries.
    ///   - secret: The endpoint secret, `whsec_` followed by the base64 key.
    ///   - tolerance: Maximum clock distance in seconds; rejects replays.
    ///   - now: The reference time. Defaults to the current date.
    public static func verify(
        body: Data,
        id: String,
        timestamp: String,
        signatureHeader: String,
        secret: String,
        tolerance: TimeInterval = defaultTolerance,
        now: Date = Date()
    ) -> Bool {
        guard secret.hasPrefix("whsec_"),
              let key = Data(base64Encoded: String(secret.dropFirst("whsec_".count))),
              !key.isEmpty,
              let seconds = TimeInterval(timestamp),
              abs(now.timeIntervalSince1970 - seconds) <= tolerance else { return false }

        let signedContent = Data("\(id).\(timestamp).".utf8) + body
        let symmetricKey = SymmetricKey(data: key)
        return signatureHeader.split(separator: " ").contains { entry in
            guard entry.hasPrefix("v1,"),
                  let mac = Data(base64Encoded: String(entry.dropFirst(3))) else { return false }
            return HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: signedContent, using: symmetricKey)
        }
    }

    /// Objective-C form of ``verify(body:id:timestamp:signatureHeader:secret:tolerance:now:)``
    /// using ``defaultTolerance`` and the current date.
    @objc(verifyBody:webhookId:timestamp:signatureHeader:secret:)
    public static func verify(body: Data, id: String, timestamp: String,
                              signatureHeader: String, secret: String) -> Bool {
        verify(body: body, id: id, timestamp: timestamp, signatureHeader: signatureHeader,
               secret: secret, tolerance: defaultTolerance, now: Date())
    }
}

extension WebhookSignature: @unchecked Sendable {}
