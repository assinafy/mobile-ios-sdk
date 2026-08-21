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

    func testSandboxHostEnablesOnlyKnownRequestCompatibility() {
        let sandbox = AssinafyClient(
            apiKey: "test-key",
            defaultAccountId: "account-id",
            baseURL: "https://sandbox.assinafy.com.br/v1"
        )
        let production = AssinafyClient(apiKey: "test-key", defaultAccountId: "account-id")

        XCTAssertTrue(sandbox.documents.usesSandboxCompatibility)
        XCTAssertTrue(sandbox.assignments.usesSandboxCompatibility)
        XCTAssertFalse(production.documents.usesSandboxCompatibility)
        XCTAssertFalse(production.assignments.usesSandboxCompatibility)
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
