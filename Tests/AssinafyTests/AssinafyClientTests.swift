import XCTest
@testable import Assinafy

final class AssinafyClientTests: XCTestCase {

    func testConfigurationInitialisation() {
        let config = AssinafyClientConfiguration(
            apiKey: "test-key",
            baseURL: "https://api.test.com",
            defaultAccountId: "acc-123",
            timeout: 60
        )
        XCTAssertEqual(config.apiKey, "test-key")
        XCTAssertEqual(config.baseURL, "https://api.test.com")
        XCTAssertEqual(config.defaultAccountId, "acc-123")
        XCTAssertEqual(config.timeout, 60)
    }

    func testConfigurationValidationRejectsUnsafeSettings() {
        let invalid = [
            AssinafyClientConfiguration(apiKey: "key", token: "token"),
            AssinafyClientConfiguration(apiKey: " "),
            AssinafyClientConfiguration(token: "token\nvalue"),
            AssinafyClientConfiguration(baseURL: "http://api.test.com/v1"),
            AssinafyClientConfiguration(baseURL: "https://user:pass@api.example.invalid/v1"),
            AssinafyClientConfiguration(baseURL: "https://api.test.com/v1?key=value"),
            AssinafyClientConfiguration(defaultAccountId: ".."),
            AssinafyClientConfiguration(defaultAccountId: "account\nvalue"),
            AssinafyClientConfiguration(timeout: 0),
            AssinafyClientConfiguration(timeout: .infinity),
        ]

        for config in invalid {
            XCTAssertThrowsError(try config.validate()) { error in
                XCTAssertTrue(error is ValidationError)
            }
        }
    }

    func testObjectiveCCompatibleConfigurationInitializer() throws {
        let config = AssinafyClientConfiguration(
            apiKey: nil,
            token: "test-token",
            baseURL: "https://api.test.com/v1",
            defaultAccountId: "account-id",
            timeout: 45
        )

        try config.validate()
        XCTAssertEqual(config.token, "test-token")
        XCTAssertEqual(config.timeout, 45)
    }

    func testClientCanCrossSwiftConcurrencyBoundary() async {
        let client = AssinafyClient(configuration: AssinafyClientConfiguration())
        let version = await Task.detached { [client] in
            _ = client.documents
            return AssinafyClient.sdkVersion
        }.value
        // The release version itself is pinned by CI against the changelog and
        // README; this test only needs the value to survive the hop.
        XCTAssertEqual(version, AssinafyClient.sdkVersion)
        XCTAssertEqual(
            version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression)?.upperBound,
            version.endIndex
        )
    }

    func testConfigurationValidationAcceptsPublicAndAuthenticatedClients() throws {
        try AssinafyClientConfiguration().validate()
        try AssinafyClientConfiguration(
            apiKey: "test-key",
            baseURL: " https://api.test.com/v1/ ",
            defaultAccountId: "account-id",
            timeout: 0.5
        ).validate()
    }

    func testInvalidConfigurationFailsClosedBeforeNetwork() async {
        let client = AssinafyClient(apiKey: "test-key", baseURL: "http://api.test.com/v1")

        await assertThrowsValidationError {
            _ = try await client.auth.currentUser()
        }
    }

    func testTokenInitialisationExposesResources() {
        let client = AssinafyClient(token: "token", defaultAccountId: "acc")
        XCTAssertNotNil(client.documents)
        XCTAssertNotNil(client.signers)
        XCTAssertNotNil(client.assignments)
        XCTAssertNotNil(client.webhooks)
        XCTAssertNotNil(client.templates)
        XCTAssertNotNil(client.tags)
        XCTAssertNotNil(client.workspaces)
        XCTAssertNotNil(client.fields)
        XCTAssertNotNil(client.auth)
    }

    func testAllowsNoCredentialsForUnauthenticatedAuthFlows() {
        let client = AssinafyClient(configuration: AssinafyClientConfiguration())
        XCTAssertNotNil(client.auth)
    }

    func testInternalInitWithMockHTTP() {
        let mock = MockHTTPClient()
        let client = AssinafyClient(http: mock, defaultAccountId: "acc")
        XCTAssertNotNil(client)
    }

    func testTrailingSlashInBaseURLIsHandled() {
        let config = AssinafyClientConfiguration(
            apiKey: "key",
            baseURL: "https://api.test.com/"
        )
        let client = AssinafyClient(configuration: config)
        XCTAssertNotNil(client)
    }

    func testSocialLoginURLRejectsInvalidConfigurationAndBlankProvider() {
        let invalid = AssinafyClient(configuration: AssinafyClientConfiguration(
            baseURL: "http://api.test.com/v1"
        ))
        XCTAssertNil(invalid.socialLoginAuthorizationURL(authClient: "google"))

        let valid = AssinafyClient(configuration: AssinafyClientConfiguration())
        XCTAssertNil(valid.socialLoginAuthorizationURL(authClient: "  "))
    }

    func testSandboxHostEnablesOnlyKnownRequestCompatibility() {
        let sandbox = AssinafyClient(
            apiKey: "test-key",
            defaultAccountId: "account-id",
            baseURL: "https://sandbox.assinafy.com.br/v1"
        )
        let production = AssinafyClient(apiKey: "test-key", defaultAccountId: "account-id")

        XCTAssertTrue(sandbox.documents.usesSandboxCompatibility)
        XCTAssertTrue(sandbox.assignments.usesSandboxCompatibility)
        XCTAssertTrue(sandbox.tags.usesSandboxCompatibility)
        XCTAssertTrue(sandbox.workspaces.usesSandboxCompatibility)
        XCTAssertFalse(production.documents.usesSandboxCompatibility)
        XCTAssertFalse(production.assignments.usesSandboxCompatibility)
        XCTAssertFalse(production.tags.usesSandboxCompatibility)
        XCTAssertFalse(production.workspaces.usesSandboxCompatibility)
    }

    func testUploadWorkflowValidatesBeforeCreatingDocument() async {
        let mock = MockHTTPClient()
        let client = AssinafyClient(http: mock, defaultAccountId: "acc")
        let options = AssinafyClient.UploadOptions(signers: [])

        await assertThrowsValidationError {
            _ = try await client.uploadAndRequestSignatures(
                documentData: Data("%PDF-1.4\n".utf8),
                options: options
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testUploadWorkflowRejectsDuplicateSignerEmailsBeforeCreatingDocument() async {
        let mock = MockHTTPClient()
        let client = AssinafyClient(http: mock, defaultAccountId: "acc")
        let options = AssinafyClient.UploadOptions(signers: [
            .init(name: "First", email: "Signer@example.com"),
            .init(name: "Second", email: "signer@example.com"),
        ])

        await assertThrowsValidationError {
            _ = try await client.uploadAndRequestSignatures(
                documentData: Data("%PDF-1.4\n".utf8),
                options: options
            )
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testUploadWorkflowCompletesAllSteps() async throws {
        let mock = MockHTTPClient()
        let client = AssinafyClient(http: mock, defaultAccountId: "acc")
        let document: [String: Any] = [
            "id": "doc-1",
            "account_id": "acc",
            "name": "document.pdf",
            "status": "metadata_ready",
            "artifacts": ["original": "https://example.com/original.pdf"],
            "pages": [],
            "created_at": "2026-08-21T12:00:00Z",
            "updated_at": "2026-08-21T12:00:00Z"
        ]
        mock.stubEnvelope(document)
        mock.stubEnvelope(document)
        mock.stubEnvelopeList([])
        mock.stubEnvelope([
            "id": "signer-1",
            "full_name": "Example Signer",
            "email": "signer@example.com"
        ])
        mock.stubEnvelope([
            "id": "assignment-1",
            "method": "virtual",
            "signers": []
        ])

        let result = try await client.uploadAndRequestSignatures(
            documentData: Data("%PDF-1.4\n".utf8),
            options: AssinafyClient.UploadOptions(signers: [
                .init(name: "Example Signer", email: "signer@example.com")
            ])
        )

        XCTAssertEqual(result.document.id, "doc-1")
        XCTAssertEqual(result.assignment.id, "assignment-1")
        XCTAssertEqual(
            mock.allRequests.map(\.path),
            [
                "/accounts/acc/documents",
                "/documents/doc-1",
                "/accounts/acc/signers",
                "/accounts/acc/signers",
                "/documents/doc-1/assignments"
            ]
        )
    }
}
