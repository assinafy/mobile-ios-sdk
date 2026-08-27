import XCTest
@testable import Assinafy

/// Pins which routes may carry the workspace credential.
///
/// The Assinafy OpenAPI document splits every operation into one of three
/// authentication classes: `bearerAuth`/`apiKeyAuth`, `signerAccessCode`, or
/// no security at all. Only the first may receive the client's `X-Api-Key` or
/// `Authorization` header. These tests assert the SDK honours that split for
/// every method reaching a public or signer-scoped route, and that the
/// transport actually withholds the headers.
final class CredentialScopeTests: XCTestCase {
    private var mock: MockHTTPClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
    }

    private func assertNoCredential(
        _ path: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let request = mock.lastRequest
        XCTAssertEqual(request?.path, path, file: file, line: line)
        XCTAssertEqual(
            request?.credential,
            APIRequest.Credential.withheld,
            "\(path) must not carry the workspace credential",
            file: file,
            line: line
        )
    }

    private func stubEmpty() {
        mock.stub(response: APIResponse(data: Data(), headers: [:], statusCode: 200))
    }

    private let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    private let documentDetailsJSON: [String: Any] = [
        "id": "doc1", "account_id": "acc", "name": "d.pdf",
        "status": "metadata_ready", "pages": [],
        "created_at": "2026-01-01", "updated_at": "2026-01-01",
    ]

    // MARK: - Routes the spec documents with `security: []`

    func testPublicAuthRoutesOmitWorkspaceCredential() async throws {
        let auth = AuthResource(http: mock)

        mock.stubEnvelope(["token": "t", "accounts": []])
        _ = try? await auth.login(LoginPayload(email: "user@example.invalid", password: "pw"))
        assertNoCredential("/login")

        mock.stubEnvelope(["token": "t", "accounts": []])
        _ = try? await auth.socialLogin(SocialLoginPayload(provider: "google", token: "tok", hasAcceptedTerms: true))
        assertNoCredential("/authentication/social-login")

        stubEmpty()
        try await auth.requestPasswordReset(
            RequestPasswordResetPayload(email: "user@example.invalid")
        )
        assertNoCredential("/authentication/request-password-reset")

        mock.stubEnvelope(["email": "user@example.invalid"])
        _ = try await auth.requestPasswordResetAndReturnResponse(
            RequestPasswordResetPayload(email: "user@example.invalid")
        )
        assertNoCredential("/authentication/request-password-reset")

        stubEmpty()
        try await auth.resetPassword(
            ResetPasswordPayload(email: "user@example.invalid", token: "t", newPassword: "pw")
        )
        assertNoCredential("/authentication/reset-password")

        mock.stubEnvelope(["email": "user@example.invalid"])
        _ = try await auth.resetPasswordAndReturnResponse(
            ResetPasswordPayload(email: "user@example.invalid", token: "t", newPassword: "pw")
        )
        assertNoCredential("/authentication/reset-password")
    }

    func testPublicDocumentRoutesOmitWorkspaceCredential() async throws {
        let documents = DocumentResource(http: mock, defaultAccountId: "acc")

        mock.stubEnvelope(["hash": "h", "is_valid": true])
        _ = try await documents.verifyDetails(signatureHash: "h")
        assertNoCredential("/documents/h/verify")

        mock.stubEnvelope(["id": "doc1", "name": "d.pdf", "status": "metadata_ready"])
        _ = try await documents.getPublicInfo(documentId: "doc1")
        assertNoCredential("/public/documents/doc1")

        stubEmpty()
        try await documents.sendPublicSignToken(documentId: "doc1", email: "user@example.invalid")
        assertNoCredential("/public/documents/doc1/send-token")
    }

    func testSandboxSendTokenCompatibilityRouteOmitsWorkspaceCredential() async throws {
        let documents = DocumentResource(
            http: mock,
            defaultAccountId: "acc",
            usesSandboxCompatibility: true
        )
        stubEmpty()
        try await documents.sendPublicSignToken(documentId: "doc1", email: "user@example.invalid")
        assertNoCredential("/public/documents/doc1/send-token")
    }

    func testPublicSignerArtifactDownloadOmitsWorkspaceCredential() async throws {
        let signers = SignerResource(http: mock, defaultAccountId: "acc")
        mock.stub(response: APIResponse(data: Data("%PDF".utf8), headers: [:], statusCode: 200))
        _ = try await signers.downloadSignerDocumentArtifact(
            signerId: "s1",
            documentId: "doc1",
            artifact: .original
        )
        assertNoCredential("/signers/s1/documents/doc1/download/original")
    }

    // MARK: - Routes the spec documents with `security: [signerAccessCode]`

    func testSignerScopedRoutesOmitWorkspaceCredential() async throws {
        let signers = SignerResource(http: mock, defaultAccountId: "acc")

        mock.stubEnvelope(["id": "s1", "full_name": "S"])
        _ = try await signers.getSelf(signerAccessCode: "code")
        assertNoCredential("/signers/self")

        stubEmpty()
        try await signers.acceptTermsWithoutResponse(signerAccessCode: "code")
        assertNoCredential("/signers/accept-terms")

        stubEmpty()
        try await signers.verifyEmail(
            payload: VerifyEmailPayload(verificationCode: "123456", signerAccessCode: "code")
        )
        assertNoCredential("/verify")

        stubEmpty()
        try await signers.uploadSignature(
            signerAccessCode: "code",
            type: .signature,
            imageData: png
        )
        assertNoCredential("/signature")

        mock.stub(response: APIResponse(data: png, headers: [:], statusCode: 200))
        _ = try await signers.downloadSignature(signerAccessCode: "code", type: .signature)
        assertNoCredential("/signature/signature")

        mock.stubEnvelope(documentDetailsJSON)
        _ = try await signers.getCurrentDocument(signerId: "s1", signerAccessCode: "code")
        assertNoCredential("/signers/s1/document")

        mock.stubEnvelopeList([])
        _ = try await signers.listSignerDocuments(signerId: "s1", signerAccessCode: "code")
        assertNoCredential("/signers/s1/documents")

        mock.stubEnvelopeList([])
        _ = try await signers.searchSignerDocuments(signerId: "s1", signerAccessCode: "code")
        assertNoCredential("/signers/s1/documents/search")

        stubEmpty()
        try await signers.signMultipleDocuments(signerAccessCode: "code", documentIds: ["doc1"])
        assertNoCredential("/signers/documents/sign-multiple")

        stubEmpty()
        try await signers.declineMultipleDocuments(
            signerAccessCode: "code",
            documentIds: ["doc1"],
            reason: "no"
        )
        assertNoCredential("/signers/documents/decline-multiple")

        mock.stubEnvelope(documentDetailsJSON)
        _ = try await signers.getSigningDocument(signerAccessCode: "code")
        assertNoCredential("/sign")
    }

    func testSignerScopedAssignmentAndConfirmDataRoutesOmitWorkspaceCredential() async throws {
        let assignments = AssignmentResource(http: mock, defaultAccountId: "acc")

        stubEmpty()
        try await assignments.sign(documentId: "doc1", assignmentId: "a1", signerAccessCode: "code")
        assertNoCredential("/documents/doc1/assignments/a1")

        stubEmpty()
        try await assignments.decline(
            documentId: "doc1",
            assignmentId: "a1",
            signerAccessCode: "code",
            reason: "no"
        )
        assertNoCredential("/documents/doc1/assignments/a1/reject")

        let documents = DocumentResource(http: mock, defaultAccountId: "acc")

        stubEmpty()
        try await documents.confirmSignerData(
            documentId: "doc1",
            signerAccessCode: "code",
            payload: ConfirmSignerDataPayload(email: "user@example.invalid")
        )
        assertNoCredential("/documents/doc1/signers/confirm-data")

        mock.stubEnvelope(["id": "s1", "full_name": "S"])
        _ = try await documents.confirmSignerDataAndReturnSigner(
            documentId: "doc1",
            signerAccessCode: "code",
            payload: ConfirmSignerDataPayload(email: "user@example.invalid")
        )
        assertNoCredential("/documents/doc1/signers/confirm-data")
    }

    // MARK: - Workspace routes keep the credential

    func testWorkspaceScopedRoutesKeepTheCredential() async throws {
        let documents = DocumentResource(http: mock, defaultAccountId: "acc")
        mock.stubEnvelopeList([])
        _ = try await documents.list()
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)

        let auth = AuthResource(http: mock)
        stubEmpty()
        try await auth.changePassword(
            ChangePasswordPayload(
                email: "user@example.invalid",
                password: "old",
                newPassword: "new"
            )
        )
        XCTAssertEqual(mock.lastRequest?.path, "/authentication/change-password")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)

        // `POST /accounts/{id}/fields/{id}/validate` accepts a signer access code
        // but is documented as workspace-authenticated, so the credential stays.
        let fields = FieldResource(http: mock, defaultAccountId: "acc")
        mock.stubEnvelope(["field_id": "f1", "success": true])
        _ = try await fields.validate(fieldId: "f1", value: "v", signerAccessCode: "code")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/acc/fields/f1/validate")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
    }

    // MARK: - Transport

    func testTransportWithholdsCredentialHeadersForUncredentialedRequests() throws {
        let client = URLSessionHTTPClient(
            baseURL: URL(string: "https://sandbox.assinafy.com.br/v1")!,
            defaultHeaders: [
                "Accept": "application/json",
                "User-Agent": "assinafy-ios-sdk/test",
                "X-Api-Key": "secret-key",
                "Authorization": "Bearer secret-token",
            ]
        )

        let credentialed = try client.buildURLRequest(from: .get("/accounts"))
        XCTAssertEqual(credentialed.value(forHTTPHeaderField: "X-Api-Key"), "secret-key")
        XCTAssertEqual(
            credentialed.value(forHTTPHeaderField: "Authorization"),
            "Bearer secret-token"
        )

        let publicRequest = try client.buildURLRequest(
            from: APIRequest.get("/sign").withoutWorkspaceCredential()
        )
        XCTAssertNil(publicRequest.value(forHTTPHeaderField: "X-Api-Key"))
        XCTAssertNil(publicRequest.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(publicRequest.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(
            publicRequest.value(forHTTPHeaderField: "User-Agent"),
            "assinafy-ios-sdk/test"
        )
    }

    func testCredentialHeaderMatchingIsCaseInsensitive() throws {
        let client = URLSessionHTTPClient(
            baseURL: URL(string: "https://sandbox.assinafy.com.br/v1")!,
            defaultHeaders: ["x-api-key": "secret-key", "authorization": "Bearer secret-token"]
        )
        let request = try client.buildURLRequest(
            from: APIRequest.get("/sign").withoutWorkspaceCredential()
        )
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Api-Key"))
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testWithoutWorkspaceCredentialPreservesEveryOtherField() throws {
        let original = APIRequest(
            method: .put,
            path: "/signers/accept-terms",
            queryItems: [URLQueryItem(name: "signer-access-code", value: "code")],
            body: Data("body".utf8),
            contentType: "image/png"
        )
        let stripped = original.withoutWorkspaceCredential()
        XCTAssertEqual(stripped.method, original.method)
        XCTAssertEqual(stripped.path, original.path)
        XCTAssertEqual(stripped.queryItems, original.queryItems)
        XCTAssertEqual(stripped.body, original.body)
        XCTAssertEqual(stripped.contentType, original.contentType)
        XCTAssertEqual(original.credential, .workspace)
        XCTAssertEqual(stripped.credential, .withheld)
    }
}
