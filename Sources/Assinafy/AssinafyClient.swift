import Foundation

// MARK: - AssinafyClientConfiguration

/// Configuration options for ``AssinafyClient``.
///
/// Use ``AssinafyClientConfiguration/init(apiKey:baseURL:defaultAccountId:timeout:logger:)``
/// to fully customise behaviour, or the convenience `apiKey` / `token` factory
/// methods on ``AssinafyClient`` for the common case. Leave credentials empty
/// when you only need unauthenticated endpoints such as login or password reset.
@objcMembers
public final class AssinafyClientConfiguration: NSObject {
    /// Production API base URL from the official Assinafy API documentation
    /// (https://api.assinafy.com.br/v1/docs).
    public static let productionBaseURL = "https://api.assinafy.com.br/v1"

    /// API key used for `X-Api-Key` authentication.
    public let apiKey: String?
    /// Bearer token used for `Authorization: Bearer` authentication.
    public let token: String?
    /// Base URL for all API requests. Defaults to `https://api.assinafy.com.br/v1`.
    public let baseURL: String
    /// Default account (workspace) ID applied when individual calls omit an explicit ID.
    public let defaultAccountId: String?
    /// Request timeout in seconds. Defaults to `30`.
    public let timeout: TimeInterval
    /// Logger for internal SDK events. Defaults to ``NoopLogger``.
    public let logger: Logger

    /// Creates a configuration object.
    ///
    /// - Parameters:
    ///   - apiKey: API key for `X-Api-Key` auth (mutually exclusive with `token`).
    ///   - token: Bearer token for `Authorization` auth (mutually exclusive with `apiKey`).
    ///   - baseURL: Override the default API base URL.
    ///   - defaultAccountId: Pre-set the workspace account ID.
    ///   - timeout: Connection and read timeout in seconds.
    ///   - logger: Logger to receive internal SDK events.
    public init(
        apiKey: String? = nil,
        token: String? = nil,
        baseURL: String = AssinafyClientConfiguration.productionBaseURL,
        defaultAccountId: String? = nil,
        timeout: TimeInterval = 30,
        logger: Logger = NoopLogger()
    ) {
        self.apiKey = apiKey
        self.token = token
        self.baseURL = baseURL
        self.defaultAccountId = defaultAccountId
        self.timeout = timeout
        self.logger = logger
    }
}

extension AssinafyClientConfiguration: @unchecked Sendable {}

// MARK: - AssinafyClient

/// The main entry point for the Assinafy SDK.
///
/// Create a single shared instance and hold a strong reference to it.
///
/// ## Initialisation
/// ```swift
/// // API key authentication (server-side use)
/// let client = AssinafyClient(apiKey: "your-api-key", defaultAccountId: "acc_id")
///
/// // Bearer token authentication
/// let client = AssinafyClient(token: "your-bearer-token")
/// ```
///
/// ## Resources
/// The client exposes one resource object per API domain:
/// - ``documents`` — Upload, list, and manage documents.
/// - ``signers`` — Create and look up signers.
/// - ``assignments`` — Create and manage signing assignments.
/// - ``webhooks`` — Register and query webhook subscriptions.
/// - ``templates`` — Browse reusable document templates.
/// - ``tags`` — Manage workspace tags and document tag attachments.
/// - ``workspaces`` — Manage workspaces (accounts).
/// - ``fields`` — Manage workspace field definitions and validation.
/// - ``auth`` — Login, password reset, and API key management.
///
/// ## Objective-C
/// ```objc
/// ASFAssinafyClient *client = [[ASFAssinafyClient alloc] initWithApiKey:@"key"
///                                                         defaultAccountId:@"acc"];
/// [client.signers getSignerWithId:@"sig_id" accountId:nil completion:^(ASFSigner *s, NSError *e) {
///     NSLog(@"%@", s.fullName);
/// }];
/// ```
@objcMembers
@objc(ASFAssinafyClient)
public final class AssinafyClient: NSObject {

    /// The SDK version string included in the `User-Agent` header.
    public static let sdkVersion = "1.2.1"

    // MARK: Resources

    /// Manages document uploads, details, and artifact downloads.
    public let documents: DocumentResource
    /// Manages signer creation, lookup, and updates.
    public let signers: SignerResource
    /// Manages signing assignments linking documents to signers.
    public let assignments: AssignmentResource
    /// Manages webhook subscriptions and delivery history.
    public let webhooks: WebhookResource
    /// Provides read access to document templates.
    public let templates: TemplateResource
    /// Manages workspace tags and document tag attachments.
    public let tags: TagResource
    /// Manages workspace (account) objects.
    public let workspaces: WorkspaceResource
    /// Manages workspace field definitions and validation.
    public let fields: FieldResource
    /// Manages login, password, social login, and API key endpoints.
    public let auth: AuthResource

    private let http: HTTPClientProtocol
    private let config: AssinafyClientConfiguration

    // MARK: Designated initialiser

    /// Creates a client with a full configuration object.
    ///
    /// - Parameter configuration: All client settings.
    @objc public init(configuration: AssinafyClientConfiguration) {
        let baseURL = Self.normaliseBaseURL(configuration.baseURL)
        var headers: [String: String] = [
            "Accept": "application/json",
            "User-Agent": "assinafy-ios-sdk/\(AssinafyClient.sdkVersion)",
        ]
        if let key = configuration.apiKey {
            headers["X-Api-Key"] = key
        } else if let tok = configuration.token {
            headers["Authorization"] = "Bearer \(tok)"
        }
        let http = URLSessionHTTPClient(
            baseURL: baseURL,
            defaultHeaders: headers,
            timeout: configuration.timeout
        )
        self.http = http
        self.config = configuration
        let accountId = configuration.defaultAccountId
        let logger    = configuration.logger
        documents   = DocumentResource(http: http, defaultAccountId: accountId, logger: logger)
        signers     = SignerResource(http: http, defaultAccountId: accountId, logger: logger)
        assignments = AssignmentResource(http: http, defaultAccountId: accountId, logger: logger)
        webhooks    = WebhookResource(http: http, defaultAccountId: accountId, logger: logger)
        templates   = TemplateResource(http: http, defaultAccountId: accountId, logger: logger)
        tags        = TagResource(http: http, defaultAccountId: accountId, logger: logger)
        workspaces  = WorkspaceResource(http: http, defaultAccountId: accountId, logger: logger)
        fields      = FieldResource(http: http, defaultAccountId: accountId, logger: logger)
        auth        = AuthResource(http: http, defaultAccountId: accountId, logger: logger)
        super.init()
    }

    // MARK: Convenience initialisers

    /// Creates a client authenticated with an API key.
    ///
    /// - Parameters:
    ///   - apiKey: Your Assinafy API key.
    ///   - defaultAccountId: Pre-set workspace ID applied to all resource calls.
    ///   - baseURL: Override the default API base URL.
    @objc public convenience init(
        apiKey: String,
        defaultAccountId: String? = nil,
        baseURL: String = AssinafyClientConfiguration.productionBaseURL
    ) {
        self.init(configuration: AssinafyClientConfiguration(
            apiKey: apiKey,
            baseURL: baseURL,
            defaultAccountId: defaultAccountId
        ))
    }

    /// Creates a client authenticated with a bearer token.
    ///
    /// - Parameters:
    ///   - token: Your Assinafy bearer token.
    ///   - defaultAccountId: Pre-set workspace ID applied to all resource calls.
    @objc public convenience init(
        token: String,
        defaultAccountId: String? = nil
    ) {
        self.init(configuration: AssinafyClientConfiguration(
            token: token,
            defaultAccountId: defaultAccountId
        ))
    }

    // MARK: Internal test initialiser

    /// Initialises the client with a custom HTTP transport (used in unit tests).
    init(http: HTTPClientProtocol, defaultAccountId: String? = nil, logger: Logger = NoopLogger()) {
        self.http = http
        self.config = AssinafyClientConfiguration(apiKey: "test", defaultAccountId: defaultAccountId)
        documents   = DocumentResource(http: http, defaultAccountId: defaultAccountId, logger: logger)
        signers     = SignerResource(http: http, defaultAccountId: defaultAccountId, logger: logger)
        assignments = AssignmentResource(http: http, defaultAccountId: defaultAccountId, logger: logger)
        webhooks    = WebhookResource(http: http, defaultAccountId: defaultAccountId, logger: logger)
        templates   = TemplateResource(http: http, defaultAccountId: defaultAccountId, logger: logger)
        tags        = TagResource(http: http, defaultAccountId: defaultAccountId, logger: logger)
        workspaces  = WorkspaceResource(http: http, defaultAccountId: defaultAccountId, logger: logger)
        fields      = FieldResource(http: http, defaultAccountId: defaultAccountId, logger: logger)
        auth        = AuthResource(http: http, defaultAccountId: defaultAccountId, logger: logger)
        super.init()
    }

    // MARK: - High-level helpers

    /// Options for ``uploadAndRequestSignatures(documentData:options:accountId:)``.
    @objcMembers
    public final class UploadOptions: NSObject {
        /// Signers to assign to the document after upload.
        public var signers: [SignerInput]
        /// Custom message sent to signers with the assignment notification.
        public var message: String?
        /// Optional expiry date string (ISO-8601) for the signing assignment.
        public var expiresAt: String?
        /// Override the client's default account ID.
        public var accountId: String?

        @objc public init(signers: [SignerInput]) {
            self.signers = signers
        }
    }

    /// A signer descriptor for the ``uploadAndRequestSignatures(documentData:options:accountId:)`` helper.
    @objcMembers
    public final class SignerInput: NSObject {
        public var name: String
        public var email: String
        public var whatsappPhoneNumber: String?
        public var cpf: String?

        @objc public init(name: String, email: String) {
            self.name = name
            self.email = email
        }
    }

    /// Convenience helper that uploads a document, creates all signers, and starts the signing
    /// assignment in a single call.
    ///
    /// The workflow is:
    /// 1. Upload the PDF.
    /// 2. Wait for the document to reach `metadataReady` status.
    /// 3. Create (or reuse) each signer by email.
    /// 4. Create the assignment with all signers.
    ///
    /// - Parameters:
    ///   - documentData: The raw PDF bytes to upload.
    ///   - options: Signer list, message, expiry, and account ID.
    ///   - accountId: Override the client's default account ID.
    /// - Returns: A tuple of the ``DocumentUploadResponse`` and the created ``Assignment``.
    public func uploadAndRequestSignatures(
        documentData: Data,
        options: UploadOptions,
        accountId: String? = nil
    ) async throws -> (document: DocumentUploadResponse, assignment: Assignment) {
        let acct = accountId ?? options.accountId
        let uploadOpts = DocumentUploadOptions(accountId: acct)
        let document = try await documents.upload(documentData, options: uploadOpts)
        _ = try await documents.waitUntilReady(documentId: document.id)

        let signerObjects: [Signer] = try await withThrowingTaskGroup(of: Signer.self) { group in
            for input in options.signers {
                let payload = CreateSignerPayload(
                    fullName: input.name,
                    email: input.email,
                    whatsappPhoneNumber: input.whatsappPhoneNumber,
                    cpf: input.cpf
                )
                group.addTask { [weak self] in
                    guard let self else { throw AssinafySDKError("Client deallocated") }
                    return try await self.signers.create(payload, accountId: acct)
                }
            }
            var result: [Signer] = []
            for try await s in group { result.append(s) }
            return result
        }

        let payload = CreateAssignmentPayload.withSignerIds(
            signerObjects.map(\.id),
            method: .virtual,
            message: options.message,
            expiresAt: options.expiresAt
        )
        let assignment = try await assignments.create(
            documentId: document.id,
            payload: payload
        )
        return (document, assignment)
    }

    // MARK: - Private

    private static func normaliseBaseURL(_ raw: String) -> URL {
        var str = raw.trimmingCharacters(in: .whitespaces)
        while str.hasSuffix("/") { str.removeLast() }
        guard let url = URL(string: str) else {
            preconditionFailure("AssinafyClient: invalid baseURL '\(raw)'")
        }
        return url
    }
}

extension AssinafyClient.UploadOptions: @unchecked Sendable {}

extension AssinafyClient.SignerInput: @unchecked Sendable {}
