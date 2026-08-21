import Foundation

// MARK: - MultipartFormData

/// Incrementally builds a `multipart/form-data` request body with a unique boundary.
///
/// Shared by the document and template upload paths so both produce identical,
/// well-formed multipart payloads.
struct MultipartFormData {
    private var body = Data()

    /// The generated multipart boundary token.
    let boundary: String

    init() {
        boundary = "AssinafyBoundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }

    /// The `Content-Type` header value to send alongside ``finalized()``.
    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    /// Appends a simple text field part.
    mutating func addField(name: String, value: String) {
        body.append("--\(boundary)\r\n".utf8Data)
        body.append("Content-Disposition: form-data; name=\"\(quoted(name))\"\r\n\r\n".utf8Data)
        body.append(value.utf8Data)
        body.append("\r\n".utf8Data)
    }

    /// Appends a binary file part.
    mutating func addFile(name: String, filename: String, contentType: String, data: Data) {
        body.append("--\(boundary)\r\n".utf8Data)
        body.append("Content-Disposition: form-data; name=\"\(quoted(name))\"; filename=\"\(quoted(filename))\"\r\n".utf8Data)
        body.append("Content-Type: \(safeContentType(contentType))\r\n\r\n".utf8Data)
        body.append(data)
        body.append("\r\n".utf8Data)
    }

    /// Returns the complete body, terminated with the closing boundary.
    func finalized() -> Data {
        var out = body
        out.append("--\(boundary)--\r\n".utf8Data)
        return out
    }
}

private func quoted(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\r", with: "")
        .replacingOccurrences(of: "\n", with: "")
}

private func safeContentType(_ value: String) -> String {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$&^_.+-/")
    return value.rangeOfCharacter(from: allowed.inverted) == nil && value.contains("/")
        ? value
        : "application/octet-stream"
}

// MARK: - PDFValidation

/// Shared client-side validation for PDF uploads (document and template).
enum PDFValidation {
    /// Maximum accepted upload size, matching the platform limit (25 MB).
    static let maxFileSizeBytes = 25 * 1024 * 1024

    private static let magicBytes: [UInt8] = [0x25, 0x50, 0x44, 0x46] // "%PDF"

    /// Validates that `data` is a non-empty PDF within the size limit.
    ///
    /// - Throws: ``ValidationError`` when the data is too small, not a PDF, or too large.
    static func validate(_ data: Data) throws {
        guard data.count > 4 else {
            throw ValidationError("File data is empty or too small to be a PDF")
        }
        guard [UInt8](data.prefix(4)) == magicBytes else {
            throw ValidationError("File must be a valid PDF document")
        }
        guard data.count <= maxFileSizeBytes else {
            throw ValidationError("File size must not exceed 25 MB")
        }
    }
}
