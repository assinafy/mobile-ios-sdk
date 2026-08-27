import XCTest
@testable import Assinafy

/// Compiles every API shape shown in `README.md`.
///
/// The bodies never execute; the value is that a documented call which stops
/// compiling — a renamed argument, a removed overload — fails the build instead
/// of silently rotting in the README.
final class ReadmeSnippetsCompileTests: XCTestCase {

    func testReadmeSnippetsCompile() {
        XCTAssertNotNil(Self.self)
    }

    @available(*, unavailable)
    private func quickStart(bearerToken: String, accountId: String, pdfData: Data) async throws {
        let client = AssinafyClient(token: bearerToken, defaultAccountId: accountId)
        let uploaded = try await client.documents.upload(pdfData)
        let document = try await client.documents.waitUntilReady(documentId: uploaded.id)
        let signer = try await client.signers.create(
            CreateSignerPayload(fullName: "Ana Souza", email: "ana@example.invalid")
        )
        _ = try await client.assignments.create(
            documentId: document.id,
            payload: .withSignerIds([signer.id], method: .virtual, message: "Please review and sign.")
        )
    }

    @available(*, unavailable)
    private func configuration(bearerToken: String, accountId: String) throws {
        let configuration = AssinafyClientConfiguration(
            token: bearerToken,
            baseURL: AssinafyClientConfiguration.productionBaseURL,
            defaultAccountId: accountId,
            timeout: 30,
            logger: NoopLogger()
        )
        try configuration.validate()
        _ = AssinafyClient(configuration: configuration)
        _ = AssinafyClient(configuration: AssinafyClientConfiguration())
    }

    @available(*, unavailable)
    private func lifecycle(
        client: AssinafyClient,
        accountId: String,
        pdfData: Data,
        roleId: String,
        hash: String
    ) async throws {
        let uploaded = try await client.documents.upload(
            pdfData,
            options: DocumentUploadOptions(accountId: accountId)
        )
        let document = try await client.documents.waitUntilReady(
            documentId: uploaded.id,
            options: WaitUntilReadyOptions(maxWaitSeconds: 60, pollIntervalSeconds: 2)
        )
        let signer = try await client.signers.create(
            CreateSignerPayload(fullName: "Ana Souza", email: "ana@example.invalid")
        )
        let request = CreateAssignmentPayload.withSignerIds(
            [signer.id],
            method: .virtual,
            message: "Please review and sign."
        )
        let estimate = try await client.assignments.estimateCost(
            documentId: document.id,
            payload: request
        )
        guard estimate.hasSufficientResources else {
            throw AssinafySDKError(estimate.blockingReason ?? "Insufficient account resources")
        }
        _ = estimate.breakdown
        _ = estimate.documentBalance
        _ = estimate.creditBalance
        _ = try await client.assignments.create(documentId: document.id, payload: request)
        _ = try await client.documents.getSigningProgress(documentId: document.id)
        _ = try await client.documents.isFullySigned(documentId: document.id)
        _ = try await client.documents.activities(documentId: document.id)
        _ = try await client.documents.downloadArtifact(
            documentId: document.id,
            artifact: .certificated
        )
        _ = try await client.documents.verifyDetails(signatureHash: hash)
        _ = SignerReference.descriptor(
            id: signer.id,
            verificationMethod: "Email",
            notificationMethods: ["Email"],
            step: 1
        )
        _ = try await client.documents.createFromTemplate(
            templateId: "template",
            signers: [TemplateSigner(roleId: roleId, id: signer.id)],
            options: CreateDocumentFromTemplateOptions(name: "Offer letter")
        )
        _ = try await client.templates.list(params: TemplateListParams(search: "Hiring"))
    }

    @available(*, unavailable)
    private func convenienceFlow(client: AssinafyClient, pdfData: Data) async throws {
        let options = AssinafyClient.UploadOptions(signers: [
            AssinafyClient.SignerInput(name: "Ana Souza", email: "ana@example.invalid"),
        ])
        options.message = "Please review and sign."
        _ = try await client.uploadAndRequestSignatures(documentData: pdfData, options: options)
    }

    @available(*, unavailable)
    private func signerFlow(
        client: AssinafyClient,
        documentId: String,
        assignmentId: String,
        accessCode: String,
        pngData: Data
    ) async throws {
        _ = try await client.signers.getSelf(signerAccessCode: accessCode)
        try await client.signers.acceptTermsWithoutResponse(signerAccessCode: accessCode)
        _ = try await client.documents.confirmSignerDataAndReturnSigner(
            documentId: documentId,
            signerAccessCode: accessCode,
            payload: ConfirmSignerDataPayload(
                fullName: "Ana Souza",
                email: "ana@example.invalid",
                hasAcceptedTerms: true
            )
        )
        try await client.assignments.sign(
            documentId: documentId,
            assignmentId: assignmentId,
            signerAccessCode: accessCode
        )
        try await client.assignments.decline(
            documentId: documentId,
            assignmentId: assignmentId,
            signerAccessCode: accessCode,
            reason: "Wrong recipient"
        )
        try await client.signers.signMultipleDocuments(
            signerAccessCode: accessCode,
            documentIds: [documentId]
        )
        try await client.signers.declineMultipleDocuments(
            signerAccessCode: accessCode,
            documentIds: [documentId],
            reason: "Wrong recipient"
        )
        _ = try await client.signers.listSignerDocuments(
            signerId: "signer",
            signerAccessCode: accessCode
        )
        _ = try await client.signers.searchSignerDocuments(
            signerId: "signer",
            signerAccessCode: accessCode
        )
        try await client.signers.uploadSignature(
            signerAccessCode: accessCode,
            type: .signature,
            imageData: pngData,
            reuse: true
        )
        _ = try await client.signers.getSigningDocument(signerAccessCode: accessCode)
        _ = try await client.documents.getPublicInfo(documentId: documentId)
        try await client.documents.sendPublicSignToken(
            documentId: documentId,
            email: "ana@example.invalid"
        )
    }

    @available(*, unavailable)
    private func tagsFieldsWorkspacesWebhooks(
        client: AssinafyClient,
        documentId: String,
        fieldId: String,
        pngData: Data
    ) async throws {
        let tag = try await client.tags.create(
            CreateTagPayload(name: "Contracts", color: "ff8800")
        )
        _ = try await client.tags.appendDocumentTags(documentId: documentId, tagIds: [tag.id])
        _ = try await client.tags.replaceDocumentTags(documentId: documentId, tagIds: [])
        _ = try await client.fields.validate(fieldId: fieldId, value: JSONValue(.integer(42)))
        _ = try await client.fields.validateMultiple(items: [
            FieldValidateMultipleItem(fieldId: fieldId, value: "2026-08-27"),
        ])
        _ = try await client.workspaces.theme()
        try await client.workspaces.uploadLogo(pngData)
        _ = try await client.webhooks.register(
            WebhookRegisterPayload(
                url: "https://example.invalid/hooks/assinafy",
                email: "ops@example.invalid",
                events: ["document.completed"]
            )
        )
        _ = try await client.webhooks.listEventTypes()
        let attempts = try await client.webhooks.listDispatches()
        _ = try await client.webhooks.retryDispatch(dispatchId: attempts.data[0].id)
        try await client.webhooks.inactivate()
    }

    @available(*, unavailable)
    private func pagination(client: AssinafyClient) async throws {
        var page = 1
        var all: [DocumentListItem] = []
        repeat {
            let result = try await client.documents.list(
                params: ListParams(page: page, perPage: 100)
            )
            all += result.data
            guard let meta = result.meta, page < meta.lastPage else { break }
            page += 1
        } while true
        _ = all
    }

    @available(*, unavailable)
    private func errorHandling(client: AssinafyClient, documentId: String) async {
        do {
            _ = try await client.documents.get(documentId: documentId)
        } catch let error as APIError {
            print(error.statusCode, error.message, error.responseData as Any)
            for restriction in error.workspaceDeletionRestrictions {
                print(restriction.code, restriction.accountIds)
            }
        } catch let error as ValidationError {
            print(error.message, error.errors)
        } catch let error as NetworkError {
            print(error.message, error.underlyingError as Any)
        } catch is CancellationError {
        } catch {
        }
    }

    @available(*, unavailable)
    private func lowLevelRequestAPI() {
        let request = APIRequest.get("/sign").withoutWorkspaceCredential()
        _ = request.credential
    }

    @available(*, unavailable)
    private func untypedJSONAccessors(
        activity: DocumentActivity,
        item: AssignmentItem,
        placement: TemplateFieldPlacement,
        dispatch: WebhookDispatch
    ) {
        _ = activity.originJSON
        _ = activity.payloadJSON
        _ = item.valueJSON
        _ = placement.displaySettingsJSON
        _ = dispatch.payloadJSON
    }
}
