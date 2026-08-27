import XCTest
@testable import Assinafy

final class AssinafyLiveTests: XCTestCase {
    private struct LiveCredentials {
        let apiKey: String
        let accountId: String
        let baseURL: String
    }

    private func credentials() throws -> LiveCredentials {
        let env = ProcessInfo.processInfo.environment
        guard let apiKey = env["ASSINAFY_API_KEY"], !apiKey.isEmpty,
              let accountId = env["ASSINAFY_ACCOUNT_ID"], !accountId.isEmpty else {
            throw XCTSkip("Set ASSINAFY_API_KEY and ASSINAFY_ACCOUNT_ID to run live API tests.")
        }
        let baseURL = env["ASSINAFY_BASE_URL"].flatMap { $0.isEmpty ? nil : $0 }
            ?? "https://sandbox.assinafy.com.br/v1"
        guard let components = URLComponents(string: baseURL),
              components.scheme == "https",
              components.host == "sandbox.assinafy.com.br",
              components.port == nil,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "v1" else {
            throw XCTSkip("Live tests are restricted to https://sandbox.assinafy.com.br/v1.")
        }
        return LiveCredentials(apiKey: apiKey, accountId: accountId, baseURL: baseURL)
    }

    private func liveClient() throws -> AssinafyClient {
        let creds = try credentials()
        return AssinafyClient(apiKey: creds.apiKey, defaultAccountId: creds.accountId, baseURL: creds.baseURL)
    }

    private func uniqueName(_ prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.prefix(8))"
    }

    private func requiresMutationOptIn() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["ASSINAFY_RUN_LIVE_MUTATIONS"] == "1" else {
            throw XCTSkip("Set ASSINAFY_RUN_LIVE_MUTATIONS=1 to run sandbox mutation tests.")
        }
    }

    private func notificationRecipients() throws -> (String, String) {
        let env = ProcessInfo.processInfo.environment
        guard let first = env["ASSINAFY_TEST_EMAIL_A"], !first.isEmpty,
              let second = env["ASSINAFY_TEST_EMAIL_B"], !second.isEmpty,
              first.caseInsensitiveCompare(second) != .orderedSame else {
            throw XCTSkip("Set distinct ASSINAFY_TEST_EMAIL_A and ASSINAFY_TEST_EMAIL_B recipients.")
        }
        return (first, second)
    }

    private func allowingSandboxNotFound<T>(
        _ operation: () async throws -> T
    ) async throws -> T? {
        do {
            return try await operation()
        } catch let error as APIError where error.statusCode == 404 {
            return nil
        }
    }

    private func deleteDocumentDuringCleanup(
        _ client: AssinafyClient,
        documentId: String
    ) async throws {
        do {
            _ = try await client.documents.waitUntilReady(
                documentId: documentId,
                options: WaitUntilReadyOptions(maxWaitSeconds: 60, pollIntervalSeconds: 2)
            )
        } catch let error as APIError where error.statusCode == 404 {
            return
        } catch {
            // Terminal states can still be deletable, so attempt deletion below.
        }
        _ = try await allowingSandboxNotFound {
            try await client.documents.delete(documentId: documentId)
        }
    }

    private func minimalPDF() -> Data {
        var data = Data("%PDF-1.4\n".utf8)
        var offsets: [Int] = [0]

        func appendObject(_ object: String) {
            offsets.append(data.count)
            data.append(object.utf8Data)
        }

        appendObject("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
        appendObject("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
        appendObject("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>\nendobj\n")

        let xrefOffset = data.count
        data.append("xref\n0 4\n".utf8Data)
        data.append("0000000000 65535 f \n".utf8Data)
        for offset in offsets.dropFirst() {
            data.append(String(format: "%010d 00000 n \n", offset).utf8Data)
        }
        data.append("trailer\n<< /Root 1 0 R /Size 4 >>\n".utf8Data)
        data.append("startxref\n\(xrefOffset)\n%%EOF\n".utf8Data)
        return data
    }

    private func minimalPNG() -> Data {
        Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        )!
    }

    func testLiveReadOnlyCatalogAndListEndpoints() async throws {
        let client = try liveClient()

        _ = try await client.workspaces.list()
        _ = try await client.documents.list(params: ListParams(page: 1, perPage: 1))
        _ = try await client.documents.list(params: DocumentListParams(page: 1, perPage: 1))
        _ = try await client.signers.list(params: ListParams(page: 1, perPage: 1))
        _ = try await client.templates.list(params: ListParams(page: 1, perPage: 1))
        _ = try await client.templates.list(params: TemplateListParams(search: uniqueName("no-match")))
        _ = try await client.tags.list()
        _ = try await client.fields.list()
        _ = try await client.fields.listFieldTypes()
        _ = try await client.documents.listStatuses()
        _ = try await client.webhooks.listEventTypes()
    }

    /// Exercises account, user, document, assignment, webhook, and optional
    /// sandbox read contracts without changing remote state.
    func testLiveContractReadEndpoints() async throws {
        let creds = try credentials()
        let client = try liveClient()

        let workspace = try await client.workspaces.get(workspaceId: creds.accountId)
        XCTAssertTrue(
            workspace.id == creds.accountId,
            "Workspace lookup returned an unexpected ID"
        )

        let theme = try await client.workspaces.theme()
        XCTAssertNotNil(theme.accountName)

        let compatibleProfile = try await client.auth.currentUser()
        let profile = try await client.auth.currentUserProfile()
        XCTAssertFalse(profile.id.isEmpty)
        XCTAssertEqual(compatibleProfile.user.id, profile.id)

        _ = try await client.documents.search(search: nil, page: 1, perPage: 1)
        _ = try await client.assignments.list(params: ListParams(page: 1, perPage: 1))
        _ = try await client.webhooks.listDispatches(
            params: WebhookDispatchListParams(page: 1, perPage: 1)
        )

        _ = try await allowingSandboxNotFound { try await client.workspaces.stats() }
        _ = try await allowingSandboxNotFound { try await client.auth.stats() }
        _ = try await allowingSandboxNotFound { try await client.workspaces.downloadLogo() }
        _ = try await allowingSandboxNotFound { try await client.webhooks.get() }
        _ = try await allowingSandboxNotFound {
            try await client.auth.getNotificationPreferences()
        }
    }

    func testLiveNotificationPreferencesRoundTripWhenAvailable() async throws {
        try requiresMutationOptIn()
        let client = try liveClient()
        let original: NotificationPreferences
        do {
            original = try await client.auth.getNotificationPreferences()
        } catch let error as APIError where error.statusCode == 404 {
            throw XCTSkip("Notification preferences are not deployed on the sandbox host.")
        }

        var operationError: Error?
        do {
            let updated = try await client.auth.updateNotificationPreferences(
                UpdateNotificationPreferencesPayload(
                    documentCompleted: NSNumber(value: !original.documentCompleted)
                )
            )
            XCTAssertEqual(updated.documentCompleted, !original.documentCompleted)
        } catch {
            operationError = error
        }

        do {
            let restored = try await client.auth.updateNotificationPreferences(
                UpdateNotificationPreferencesPayload(
                    documentCompleted: NSNumber(value: original.documentCompleted)
                )
            )
            XCTAssertEqual(restored.documentCompleted, original.documentCompleted)
        } catch {
            XCTFail("Notification-preference restoration failed: \(error.localizedDescription)")
        }
        if let operationError { throw operationError }
    }

    func testLiveDisposableWorkspaceLifecycle() async throws {
        try requiresMutationOptIn()
        let recipient = try notificationRecipients().0
        let mainWorkspaceId = try credentials().accountId
        let client = try liveClient()
        let preexistingWorkspaceIds = Set(try await client.workspaces.list().data.map(\.id))
        let workspaceName = "ios-sdk-workspace-\(UUID().uuidString.lowercased())"
        let updatedWorkspaceName = "\(workspaceName)-updated"
        var createdWorkspaceId: String?
        var operationError: Error?

        do {
            let created = try await client.workspaces.create(
                CreateWorkspacePayload(
                    name: workspaceName,
                    notificationSenderType: NotificationSenderType.user
                )
            )
            guard created.name == workspaceName,
                  created.id != mainWorkspaceId,
                  !preexistingWorkspaceIds.contains(created.id) else {
                throw AssinafySDKError(
                    "Sandbox workspace creation returned a pre-existing workspace"
                )
            }
            createdWorkspaceId = created.id

            let fetched = try await client.workspaces.get(workspaceId: created.id)
            XCTAssertEqual(fetched.id, created.id)

            let updated = try await client.workspaces.update(
                workspaceId: created.id,
                payload: UpdateWorkspacePayload(name: updatedWorkspaceName)
            )
            XCTAssertEqual(updated.name, updatedWorkspaceName)

            let theme = try await client.workspaces.theme(accountId: created.id)
            XCTAssertEqual(theme.accountName, updatedWorkspaceName)

            try await client.workspaces.uploadLogo(minimalPNG(), accountId: created.id)
            let logo = try await client.workspaces.downloadLogo(accountId: created.id)
            XCTAssertTrue(logo.starts(with: Data([0x89, 0x50, 0x4E, 0x47])))
            try await client.workspaces.deleteLogo(accountId: created.id)

            let webhook = try await client.webhooks.register(
                WebhookRegisterPayload(
                    url: "https://webhook.example.invalid/assinafy",
                    email: recipient
                ),
                accountId: created.id
            )
            XCTAssertTrue(
                webhook.email?.caseInsensitiveCompare(recipient) == .orderedSame,
                "Webhook registration returned an unexpected recipient"
            )

            let fetchedWebhook = try await client.webhooks.get(accountId: created.id)
            XCTAssertTrue(
                fetchedWebhook.email?.caseInsensitiveCompare(recipient) == .orderedSame,
                "Webhook lookup returned an unexpected recipient"
            )

            let inactiveWebhook = try await client.webhooks.inactivateAndReturn(
                accountId: created.id
            )
            XCTAssertFalse(inactiveWebhook.isActive)

            try await client.workspaces.delete(workspaceId: created.id, force: true)
            createdWorkspaceId = nil
        } catch {
            operationError = error
        }

        var cleanupError: Error?
        var cleanupIds = Set([createdWorkspaceId].compactMap { $0 })
        if operationError != nil, cleanupIds.isEmpty {
            do {
                let workspaces = try await client.workspaces.list()
                for workspace in workspaces.data
                where !preexistingWorkspaceIds.contains(workspace.id)
                    && workspace.id != mainWorkspaceId
                    && (workspace.name == workspaceName || workspace.name == updatedWorkspaceName) {
                    cleanupIds.insert(workspace.id)
                }
            } catch {
                cleanupError = error
            }
        }
        for workspaceId in cleanupIds {
            do {
                _ = try await allowingSandboxNotFound {
                    try await client.workspaces.delete(workspaceId: workspaceId, force: true)
                }
            } catch {
                cleanupError = error
            }
        }
        if let cleanupError {
            XCTFail("Workspace cleanup failed: \(cleanupError.localizedDescription)")
        }
        if let operationError { throw operationError }
    }

    /// Uploads a document, renames it via `PATCH /documents/{id}`, and cleans up.
    func testLiveDocumentRename() async throws {
        try requiresMutationOptIn()
        let client = try liveClient()
        var createdDocumentId: String?

        do {
            let uploaded = try await client.documents.upload(minimalPDF())
            createdDocumentId = uploaded.id
            _ = try await client.documents.waitUntilReady(
                documentId: uploaded.id,
                options: WaitUntilReadyOptions(maxWaitSeconds: 60, pollIntervalSeconds: 2)
            )

            let newName = uniqueName("renamed") + ".pdf"
            let renamed = try await client.documents.rename(documentId: uploaded.id, name: newName)
            XCTAssertEqual(renamed.name, newName)

            try await client.documents.delete(documentId: uploaded.id)
            createdDocumentId = nil
        } catch {
            if let createdDocumentId {
                do {
                    try await deleteDocumentDuringCleanup(client, documentId: createdDocumentId)
                } catch let cleanupError {
                    XCTFail("Document cleanup failed: \(cleanupError.localizedDescription)")
                }
            }
            throw error
        }
    }

    func testLiveTagCrud() async throws {
        try requiresMutationOptIn()
        let client = try liveClient()
        let tagName = uniqueName("ios-sdk-live")
        var createdTagIds: [String] = []
        var createdDocumentId: String?
        var operationError: Error?

        do {
            let created = try await client.tags.create(CreateTagPayload(name: tagName, color: "112233"))
            createdTagIds.append(created.id)
            XCTAssertEqual(created.name, tagName)

            let updated = try await client.tags.update(
                tagId: created.id,
                payload: UpdateTagPayload(name: "\(tagName)-updated", color: "445566")
            )
            XCTAssertEqual(updated.name, "\(tagName)-updated")

            let listed = try await client.tags.list(params: TagListParams(search: tagName))
            XCTAssertTrue(listed.data.contains { $0.id == created.id })

            let uploaded = try await client.documents.upload(minimalPDF())
            createdDocumentId = uploaded.id
            _ = try await client.documents.waitUntilReady(
                documentId: uploaded.id,
                options: WaitUntilReadyOptions(maxWaitSeconds: 60, pollIntervalSeconds: 2)
            )

            let appended = try await client.tags.appendDocumentTags(
                documentId: uploaded.id,
                tagIds: [created.id]
            )
            XCTAssertTrue(appended.contains { $0.id == created.id })
            let documentTags = try await client.tags.listDocumentTags(documentId: uploaded.id)
            XCTAssertTrue(documentTags.contains { $0.id == created.id })

            let detached = try await client.tags.detachDocumentTagAndReturnStatus(
                documentId: uploaded.id,
                tagId: created.id
            )
            XCTAssertTrue(detached)

            let replaced = try await client.tags.replaceDocumentTags(
                documentId: uploaded.id,
                tagIds: [created.id]
            )
            XCTAssertTrue(replaced.contains { $0.id == created.id })
            try await client.tags.detachDocumentTag(
                documentId: uploaded.id,
                tagId: created.id
            )
            let tagsAfterLegacyDetach = try await client.tags.listDocumentTags(
                documentId: uploaded.id
            )
            XCTAssertFalse(tagsAfterLegacyDetach.contains { $0.id == created.id })

            let deleted = try await client.tags.deleteAndReturnStatus(
                tagId: created.id,
                force: true
            )
            XCTAssertTrue(deleted)
            if deleted {
                createdTagIds.removeAll { $0 == created.id }
            }

            let legacyTag = try await client.tags.create(
                CreateTagPayload(name: uniqueName("ios-sdk-legacy-tag"))
            )
            createdTagIds.append(legacyTag.id)
            try await client.tags.delete(tagId: legacyTag.id, force: true)
            let legacyTagStillExists = try await client.tags.list(
                params: TagListParams(search: legacyTag.name)
            ).data.contains { $0.id == legacyTag.id }
            XCTAssertFalse(legacyTagStillExists)
            if !legacyTagStillExists {
                createdTagIds.removeAll { $0 == legacyTag.id }
            }

            try await client.documents.delete(documentId: uploaded.id)
            createdDocumentId = nil
        } catch {
            operationError = error
        }

        var cleanupFailures: [String] = []
        for tagId in createdTagIds {
            do {
                _ = try await allowingSandboxNotFound {
                    try await client.tags.delete(tagId: tagId, force: true)
                }
            } catch {
                cleanupFailures.append("tag \(tagId): \(error.localizedDescription)")
            }
        }
        if let createdDocumentId {
            do {
                try await deleteDocumentDuringCleanup(client, documentId: createdDocumentId)
            } catch {
                cleanupFailures.append("document: \(error.localizedDescription)")
            }
        }
        XCTAssertTrue(
            cleanupFailures.isEmpty,
            "Tag-flow cleanup failed: \(cleanupFailures.joined(separator: "; "))"
        )
        if let operationError { throw operationError }
    }

    func testLiveSignerCrud() async throws {
        try requiresMutationOptIn()
        let client = try liveClient()
        let localPart = "ios-sdk-live-\(UUID().uuidString.lowercased())"
        let email = "\(localPart)@example.com"
        var createdSignerId: String?

        do {
            guard try await client.signers.findByEmail(email) == nil else {
                throw AssinafySDKError("Disposable signer email already exists")
            }
            let created = try await client.signers.create(
                CreateSignerPayload(fullName: "iOS SDK Live Test", email: email)
            )
            guard created.email?.caseInsensitiveCompare(email) == .orderedSame else {
                throw AssinafySDKError("Signer creation returned an unexpected email")
            }
            createdSignerId = created.id

            let fetched = try await client.signers.get(signerId: created.id)
            XCTAssertEqual(fetched.id, created.id)

            let updated = try await client.signers.update(
                signerId: created.id,
                payload: UpdateSignerPayload(fullName: "iOS SDK Live Test Updated")
            )
            XCTAssertEqual(updated.fullName, "iOS SDK Live Test Updated")

            try await client.signers.delete(signerId: created.id)
            createdSignerId = nil
        } catch {
            if let createdSignerId {
                do {
                    _ = try await allowingSandboxNotFound {
                        try await client.signers.delete(signerId: createdSignerId)
                    }
                } catch let cleanupError {
                    XCTFail("Signer cleanup failed: \(cleanupError.localizedDescription)")
                }
            }
            throw error
        }
    }

    func testLiveFieldCrudAndSandboxExtensions() async throws {
        try requiresMutationOptIn()
        let client = try liveClient()
        let name = uniqueName("ios-sdk-field")
        var createdFieldId: String?

        do {
            let created = try await client.fields.create(
                CreateFieldPayload(type: "text", name: name, isRequired: true, isActive: false)
            )
            createdFieldId = created.id
            XCTAssertFalse(created.isActive)
            XCTAssertTrue(created.isRequired)

            let fetched = try await client.fields.get(fieldId: created.id)
            XCTAssertEqual(fetched.id, created.id)

            let updated = try await client.fields.update(
                fieldId: created.id,
                payload: UpdateFieldPayload(
                    type: "date",
                    name: "\(name)-updated",
                    isRequired: NSNumber(value: false),
                    isActive: NSNumber(value: true)
                )
            )
            XCTAssertEqual(updated.type, "date")
            XCTAssertFalse(updated.isRequired)
            XCTAssertTrue(updated.isActive)

            let value = "2026-08-21"
            let validation = try await client.fields.validate(
                fieldId: created.id,
                value: value
            )
            XCTAssertTrue(validation.success)
            XCTAssertEqual(validation.type, "date")

            let validations = try await client.fields.validateMultiple(items: [
                FieldValidateMultipleItem(fieldId: created.id, value: value)
            ])
            XCTAssertEqual(validations.count, 1)
            XCTAssertEqual(validations.first?.fieldId, created.id)
            XCTAssertTrue(validations.first?.success == true)

            try await client.fields.delete(fieldId: created.id)
            createdFieldId = nil
        } catch {
            if let createdFieldId {
                do {
                    _ = try await allowingSandboxNotFound {
                        try await client.fields.delete(fieldId: createdFieldId)
                    }
                } catch let cleanupError {
                    XCTFail("Field cleanup failed: \(cleanupError.localizedDescription)")
                }
            }
            throw error
        }
    }

    /// Exercises template create, get, update, and delete with a disposable resource.
    func testLiveTemplateCrudExtension() async throws {
        try requiresMutationOptIn()
        let client = try liveClient()
        let name = uniqueName("ios-sdk-template")
        var createdTemplateId: String?

        do {
            let created = try await client.templates.create(name: name, pdfData: minimalPDF())
            createdTemplateId = created.id
            XCTAssertEqual(created.name, "\(name).pdf")

            var fetched = try await client.templates.get(templateId: created.id)
            for _ in 0..<60
            where fetched.status.lowercased() != "ready"
                && fetched.status.lowercased() != "failed" {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                fetched = try await client.templates.get(templateId: created.id)
            }
            guard fetched.status.lowercased() == "ready" else {
                throw AssinafySDKError(
                    "Template did not become ready",
                    context: ["status": fetched.status]
                )
            }

            let updatedName = "\(name)-updated"
            let updated = try await client.templates.update(
                templateId: created.id,
                payload: UpdateTemplatePayload(name: updatedName)
            )
            XCTAssertEqual(updated.name, updatedName)

            try await client.templates.delete(templateId: created.id)
            createdTemplateId = nil
        } catch {
            if let createdTemplateId {
                do {
                    _ = try await allowingSandboxNotFound {
                        try await client.templates.delete(templateId: createdTemplateId)
                    }
                } catch let cleanupError {
                    XCTFail("Template cleanup failed: \(cleanupError.localizedDescription)")
                }
            }
            throw error
        }
    }

    func testLiveDocumentUploadGetDownloadDelete() async throws {
        try requiresMutationOptIn()
        let client = try liveClient()
        var createdDocumentId: String?

        do {
            let uploaded = try await client.documents.upload(minimalPDF())
            createdDocumentId = uploaded.id
            XCTAssertFalse(uploaded.id.isEmpty)

            let fetched = try await client.documents.get(documentId: uploaded.id)
            XCTAssertEqual(fetched.id, uploaded.id)

            let original = try await client.documents.downloadArtifact(
                documentId: uploaded.id,
                artifact: .original
            )
            XCTAssertTrue(original.starts(with: Data("%PDF".utf8)))

            // A freshly uploaded document is `metadata_processing`, which the
            // API reports as non-deletable. Wait until it reaches a deletable
            // state (`metadata_ready`) before cleaning up.
            _ = try await client.documents.waitUntilReady(
                documentId: uploaded.id,
                options: WaitUntilReadyOptions(maxWaitSeconds: 60, pollIntervalSeconds: 2)
            )

            let ready = try await client.documents.get(documentId: uploaded.id)
            _ = try await client.documents.activities(documentId: uploaded.id)
            let documentTags = try await client.tags.listDocumentTags(documentId: uploaded.id)
            let isFullySigned = try await client.documents.isFullySigned(documentId: uploaded.id)
            XCTAssertTrue(documentTags.isEmpty)
            XCTAssertFalse(isFullySigned)
            let progress = try await client.documents.getSigningProgress(documentId: uploaded.id)
            XCTAssertEqual(progress.total, 0)
            XCTAssertEqual(progress.signed, 0)

            if let thumbnail = try await allowingSandboxNotFound({
                try await client.documents.downloadThumbnail(documentId: uploaded.id)
            }) {
                XCTAssertFalse(thumbnail.isEmpty)
            }
            if let pageId = ready.pages.first?.id {
                let page = try await client.documents.downloadPage(
                    documentId: uploaded.id,
                    pageId: pageId
                )
                XCTAssertFalse(page.isEmpty)
            }

            try await client.documents.delete(documentId: uploaded.id)
            createdDocumentId = nil
        } catch {
            if let createdDocumentId {
                do {
                    try await deleteDocumentDuringCleanup(client, documentId: createdDocumentId)
                } catch let cleanupError {
                    XCTFail("Document cleanup failed: \(cleanupError.localizedDescription)")
                }
            }
            throw error
        }
    }

    /// Exercises the end-to-end signature-request path: upload a document,
    /// wait for processing, create signers when needed, estimate the assignment
    /// cost, and create a virtual assignment. Controlled signer fixtures are
    /// retained; the disposable document is always removed.
    func testLiveAssignmentFlow() async throws {
        try requiresMutationOptIn()
        let recipients = try notificationRecipients()
        let baseURL = try credentials().baseURL
        let client = try liveClient()
        let publicClient = AssinafyClient(configuration: AssinafyClientConfiguration(baseURL: baseURL))
        var createdDocumentId: String?
        var operationError: Error?

        do {
            let existingSignerA = try await client.signers.findByEmail(recipients.0)
            let existingSignerB = try await client.signers.findByEmail(recipients.1)

            let uploaded = try await client.documents.upload(minimalPDF())
            createdDocumentId = uploaded.id
            _ = try await client.documents.waitUntilReady(
                documentId: uploaded.id,
                options: WaitUntilReadyOptions(maxWaitSeconds: 60, pollIntervalSeconds: 2)
            )

            let signerA: Signer
            if let existingSignerA {
                signerA = existingSignerA
            } else {
                signerA = try await client.signers.create(
                    CreateSignerPayload(fullName: "Live Test Signer A", email: recipients.0)
                )
            }

            let signerB: Signer
            if let existingSignerB {
                signerB = existingSignerB
            } else {
                signerB = try await client.signers.create(
                    CreateSignerPayload(fullName: "Live Test Signer B", email: recipients.1)
                )
            }

            let payload = CreateAssignmentPayload.withSignerIds(
                [signerA.id, signerB.id],
                method: .virtual,
                message: "Assinafy iOS SDK live test"
            )

            let estimate = try await client.assignments.estimateCost(
                documentId: uploaded.id,
                payload: payload
            )
            guard estimate.hasSufficientResources else {
                if ProcessInfo.processInfo.environment["ASSINAFY_REQUIRE_LIVE_ASSIGNMENT"] == "1" {
                    throw AssinafySDKError(
                        "Sandbox account lacks the documents or credits needed for assignment creation"
                    )
                }
                throw XCTSkip("Sandbox account lacks the documents or credits needed for assignment creation.")
            }

            let assignment = try await client.assignments.create(
                documentId: uploaded.id,
                payload: payload
            )
            XCTAssertFalse(assignment.id.isEmpty)
            XCTAssertEqual(assignment.method, .virtual)
            XCTAssertEqual(assignment.signers.count, 2)

            let progress = try await client.documents.getSigningProgress(documentId: uploaded.id)
            let isFullySigned = try await client.documents.isFullySigned(documentId: uploaded.id)
            XCTAssertEqual(progress.total, 2)
            XCTAssertEqual(progress.signed, 0)
            XCTAssertFalse(isFullySigned)

            let canonicalExpiresAt = ISO8601DateFormatter().string(
                from: Date(timeIntervalSinceNow: 7 * 24 * 60 * 60)
            )
            let canonicalReset = try await client.assignments.resetExpiration(
                documentId: uploaded.id,
                assignmentId: assignment.id,
                newExpiresAt: canonicalExpiresAt
            )
            XCTAssertEqual(canonicalReset.id, assignment.id)

            let compatibleExpiresAt = ISO8601DateFormatter().string(
                from: Date(timeIntervalSinceNow: 8 * 24 * 60 * 60)
            )
            let compatibleReset = try await client.assignments.resetExpiration(
                documentId: uploaded.id,
                assignmentId: assignment.id,
                expiresAt: compatibleExpiresAt
            )
            XCTAssertEqual(compatibleReset.id, assignment.id)

            let resendCost = try await client.assignments.estimateResendCost(
                documentId: uploaded.id,
                assignmentId: assignment.id,
                signerId: signerA.id
            )
            XCTAssertFalse(resendCost.raw.isEmpty)

            let resent = try await client.assignments.resendNotification(
                documentId: uploaded.id,
                assignmentId: assignment.id,
                signerId: signerA.id
            )
            XCTAssertEqual(resent.documentId, uploaded.id)
            XCTAssertEqual(resent.signerId, signerA.id)
            XCTAssertTrue(resent.isSent)

            _ = try await client.assignments.listWhatsappNotifications(
                documentId: uploaded.id,
                assignmentId: assignment.id
            )

            let publicDocument = try await publicClient.documents.getPublicInfo(documentId: uploaded.id)
            XCTAssertEqual(publicDocument.id, uploaded.id)

            let signerArtifact = try await publicClient.signers.downloadSignerDocumentArtifact(
                signerId: signerA.id,
                documentId: uploaded.id,
                artifact: .original
            )
            XCTAssertTrue(signerArtifact.starts(with: Data("%PDF".utf8)))

            try await publicClient.documents.sendPublicSignToken(
                documentId: uploaded.id,
                email: recipients.0
            )

            let token = try await publicClient.documents.sendPublicSignToken(
                documentId: uploaded.id,
                payload: SendTokenPayload(recipient: recipients.1)
            )
            XCTAssertEqual(token.document.id, uploaded.id)
            XCTAssertEqual(token.channel, "email")
            XCTAssertTrue(
                token.recipient.caseInsensitiveCompare(recipients.1) == .orderedSame,
                "Signing-token response returned an unexpected recipient"
            )

        } catch {
            operationError = error
        }

        var cleanupFailures: [String] = []
        if let createdDocumentId {
            do {
                try await deleteDocumentDuringCleanup(client, documentId: createdDocumentId)
            } catch {
                cleanupFailures.append("document: \(error.localizedDescription)")
            }
        }
        XCTAssertTrue(
            cleanupFailures.isEmpty,
            "Assignment-flow cleanup failed: \(cleanupFailures.joined(separator: "; "))"
        )
        if let operationError { throw operationError }
    }
}
