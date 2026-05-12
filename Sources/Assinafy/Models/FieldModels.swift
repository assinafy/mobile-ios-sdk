import Foundation

// MARK: - FieldDefinition

/// A workspace field definition returned by the `/fields` endpoints.
///
/// Field definitions describe the schema for an input value collected from
/// signers (e.g. a CPF, a date, or a free-text answer). The platform ships
/// a set of predefined definitions (``isPreDefined`` is `true`); workspaces
/// can also create their own via ``FieldResource/create(_:accountId:)``.
@objcMembers
public final class FieldDefinition: NSObject {
    public let id: String
    /// Field display name.
    public let name: String
    /// Field type code (e.g. `"text"`, `"date"`, `"cpf"`).
    public let type: String
    /// Optional regex used to validate the value. Only meaningful for text-type fields.
    public let regex: String?
    /// `true` when the definition is one of the platform's built-in fields.
    public let isPreDefined: Bool
    /// `true` when the definition is active and available for use.
    public let isActive: Bool
    /// `true` when the field requires a non-empty value.
    public let isRequired: Bool
    /// `true` for built-in signature-like fields (`signature`, `initial`, `signatureDate`).
    public let isStandard: Bool
    /// `true` when the field value is read-only from the signer's perspective.
    public let isReadOnly: Bool
    /// `true` when the field is visible to signers.
    public let isVisible: Bool

    init(id: String, name: String, type: String, regex: String? = nil,
         isPreDefined: Bool = false, isActive: Bool = true, isRequired: Bool = false,
         isStandard: Bool = false, isReadOnly: Bool = false, isVisible: Bool = true) {
        self.id = id; self.name = name; self.type = type; self.regex = regex
        self.isPreDefined = isPreDefined; self.isActive = isActive
        self.isRequired = isRequired; self.isStandard = isStandard
        self.isReadOnly = isReadOnly; self.isVisible = isVisible
    }
}

extension FieldDefinition: @unchecked Sendable {}

extension FieldDefinition: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, type, regex
        case isPreDefined = "is_pre_defined"
        case isActive     = "is_active"
        case isRequired   = "is_required"
        case isStandard   = "is_standard"
        case isReadOnly   = "is_read_only"
        case isVisible    = "is_visible"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id:           try c.decode(String.self, forKey: .id),
            name:         try c.decode(String.self, forKey: .name),
            type:         try c.decode(String.self, forKey: .type),
            regex:        try c.decodeIfPresent(String.self, forKey: .regex),
            isPreDefined: try c.decodeIfPresent(Bool.self, forKey: .isPreDefined) ?? false,
            isActive:     try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true,
            isRequired:   try c.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false,
            isStandard:   try c.decodeIfPresent(Bool.self, forKey: .isStandard) ?? false,
            isReadOnly:   try c.decodeIfPresent(Bool.self, forKey: .isReadOnly) ?? false,
            isVisible:    try c.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        )
    }
}

// MARK: - CreateFieldPayload

/// Payload for `POST /accounts/{accountId}/fields`.
@objcMembers
public final class CreateFieldPayload: NSObject, Encodable {
    public let type: String
    public let name: String
    public let regex: String?
    public let isRequired: Bool
    public let isActive: Bool

    @objc public init(
        type: String,
        name: String,
        regex: String? = nil,
        isRequired: Bool = true,
        isActive: Bool = true
    ) {
        self.type = type; self.name = name; self.regex = regex
        self.isRequired = isRequired; self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case type, name, regex
        case isRequired = "is_required"
        case isActive   = "is_active"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(regex, forKey: .regex)
        try c.encode(isRequired, forKey: .isRequired)
        try c.encode(isActive, forKey: .isActive)
    }
}

extension CreateFieldPayload: @unchecked Sendable {}

// MARK: - UpdateFieldPayload

/// Payload for `PUT /accounts/{accountId}/fields/{fieldId}`.
///
/// Provide only the fields you want to change.
@objcMembers
public final class UpdateFieldPayload: NSObject, Encodable {
    public let type: String?
    public let name: String?
    public let regex: String?
    public let isRequired: NSNumber?
    public let isActive: NSNumber?

    @objc public init(
        type: String? = nil,
        name: String? = nil,
        regex: String? = nil,
        isRequired: NSNumber? = nil,
        isActive: NSNumber? = nil
    ) {
        self.type = type; self.name = name; self.regex = regex
        self.isRequired = isRequired; self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case type, name, regex
        case isRequired = "is_required"
        case isActive   = "is_active"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(type, forKey: .type)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(regex, forKey: .regex)
        if let r = isRequired { try c.encode(r.boolValue, forKey: .isRequired) }
        if let a = isActive   { try c.encode(a.boolValue, forKey: .isActive)   }
    }
}

extension UpdateFieldPayload: @unchecked Sendable {}

// MARK: - FieldListParams

/// Query parameters for ``FieldResource/list(params:accountId:)``.
@objcMembers
public final class FieldListParams: NSObject {
    /// Include inactive field definitions in the response.
    public var includeInactive: Bool
    /// Include standard built-in field types (signature, initial, signatureDate).
    public var includeStandard: Bool

    @objc public init(includeInactive: Bool = false, includeStandard: Bool = false) {
        self.includeInactive = includeInactive
        self.includeStandard = includeStandard
    }

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if includeInactive { items.append(.init(name: "include_inactive", value: "true")) }
        if includeStandard { items.append(.init(name: "include_standard", value: "true")) }
        return items
    }
}

extension FieldListParams: @unchecked Sendable {}

// MARK: - FieldValidationResult

/// Result of validating a value against a field definition.
@objcMembers
public final class FieldValidationResult: NSObject {
    public let fieldId: String?
    /// Detected type code (e.g. `"cpf"`).
    public let type: String?
    public let success: Bool
    /// Human-readable error from the platform when ``success`` is `false`.
    public let errorMessage: String

    init(fieldId: String? = nil, type: String? = nil, success: Bool, errorMessage: String) {
        self.fieldId = fieldId; self.type = type
        self.success = success; self.errorMessage = errorMessage
    }
}

extension FieldValidationResult: @unchecked Sendable {}

extension FieldValidationResult: Decodable {
    enum CodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case type, success
        case errorMessage = "error_message"
    }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            fieldId:      try c.decodeIfPresent(String.self, forKey: .fieldId),
            type:         try c.decodeIfPresent(String.self, forKey: .type),
            success:      try c.decodeIfPresent(Bool.self,   forKey: .success) ?? false,
            errorMessage: try c.decodeIfPresent(String.self, forKey: .errorMessage) ?? ""
        )
    }
}

// MARK: - FieldValidateMultipleItem

/// One entry in the body for `POST /accounts/{accountId}/fields/validate-multiple`.
@objcMembers
public final class FieldValidateMultipleItem: NSObject, Encodable {
    public let fieldId: String
    public let value: String

    @objc public init(fieldId: String, value: String) {
        self.fieldId = fieldId; self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case value
    }
}

extension FieldValidateMultipleItem: @unchecked Sendable {}

// MARK: - FieldTypeInfo

/// One entry returned by `GET /field-types`.
@objcMembers
public final class FieldTypeInfo: NSObject {
    /// The type code, used when creating a field definition (e.g. `"cpf"`).
    public let type: String
    /// Localised display label.
    public let name: String

    init(type: String, name: String) {
        self.type = type; self.name = name
    }
}

extension FieldTypeInfo: @unchecked Sendable {}

extension FieldTypeInfo: Decodable {
    enum CodingKeys: String, CodingKey { case type, name }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            type: try c.decode(String.self, forKey: .type),
            name: try c.decode(String.self, forKey: .name)
        )
    }
}
