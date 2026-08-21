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

    func testLiveReadOnlyCatalogAndListEndpoints() async throws {
        let client = try liveClient()

        _ = try await client.documents.list(params: DocumentListParams(page: 1, perPage: 1))
        _ = try await client.signers.list(params: ListParams(page: 1, perPage: 1))
        _ = try await client.templates.list(params: TemplateListParams(search: uniqueName("no-match")))
        _ = try await client.tags.list()
        _ = try await client.fields.list()
        _ = try await client.fields.listFieldTypes()
        _ = try await client.documents.listStatuses()
        _ = try await client.webhooks.listEventTypes()
    }

    /// Exercises the endpoints added during the API audit: account theme, the
    /// authenticated-user profile, lightweight document search, and the
    /// account-scoped assignment list.
    func testLiveAuditedReadEndpoints() async throws {
        let client = try liveClient()

        let theme = try await client.workspaces.theme()
        XCTAssertNotNil(theme.accountName)

        let me = try await client.auth.currentUser()
        XCTAssertFalse(me.user.id.isEmpty)
        XCTAssertFalse(me.accounts.isEmpty)

        _ = try await client.documents.search(search: nil)
        _ = try await client.assignments.list(params: ListParams(page: 1, perPage: 1))

        // The stats endpoints are production-only; tolerate a 404 on sandbox.
        do {
            _ = try await client.workspaces.stats()
        } catch let error as APIError where error.statusCode == 404 {
            // Expected on sandbox — endpoint is served on production only.
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

        let restore = UpdateNotificationPreferencesPayload(
            documentCompleted: NSNumber(value: original.documentCompleted),
            signerDeclined: NSNumber(value: original.signerDeclined),
            documentCancelled: NSNumber(value: original.documentCancelled),
            documentAboutToExpire: NSNumber(value: original.documentAboutToExpire),
            documentExpired: NSNumber(value: original.documentExpired),
            documentExpirationReset: NSNumber(value: original.documentExpirationReset),
            documentProcessingFailed: NSNumber(value: original.documentProcessingFailed),
            templateProcessingFailed: NSNumber(value: original.templateProcessingFailed),
            signerWhatsappFailed: NSNumber(value: original.signerWhatsappFailed)
        )

        do {
            let updated = try await client.auth.updateNotificationPreferences(
                UpdateNotificationPreferencesPayload(
                    documentCompleted: NSNumber(value: !original.documentCompleted)
                )
            )
            XCTAssertEqual(updated.documentCompleted, !original.documentCompleted)
            _ = try await client.auth.updateNotificationPreferences(restore)
        } catch {
            do {
                _ = try await client.auth.updateNotificationPreferences(restore)
            } catch let cleanupError {
                XCTFail("Notification-preference restore failed: \(cleanupError.localizedDescription)")
            }
            throw error
        }
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
                    try await client.documents.delete(documentId: createdDocumentId)
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
        var createdTagId: String?

        do {
            let created = try await client.tags.create(CreateTagPayload(name: tagName, color: "112233"))
            createdTagId = created.id
            XCTAssertEqual(created.name, tagName)

            let updated = try await client.tags.update(
                tagId: created.id,
                payload: UpdateTagPayload(name: "\(tagName)-updated", color: "445566")
            )
            XCTAssertEqual(updated.name, "\(tagName)-updated")

            let listed = try await client.tags.list(params: TagListParams(search: tagName))
            XCTAssertTrue(listed.data.contains { $0.id == created.id })

            try await client.tags.delete(tagId: created.id, force: true)
            createdTagId = nil
        } catch {
            if let createdTagId {
                do {
                    try await client.tags.delete(tagId: createdTagId, force: true)
                } catch let cleanupError {
                    XCTFail("Tag cleanup failed: \(cleanupError.localizedDescription)")
                }
            }
            throw error
        }
    }

    func testLiveSignerCrud() async throws {
        try requiresMutationOptIn()
        let client = try liveClient()
        let localPart = uniqueName("ios-sdk-live")
        let email = "\(localPart)@example.com"
        var createdSignerId: String?

        do {
            let created = try await client.signers.create(
                CreateSignerPayload(fullName: "iOS SDK Live Test", email: email)
            )
            createdSignerId = created.id
            XCTAssertEqual(created.email?.lowercased(), email.lowercased())

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
                    try await client.signers.delete(signerId: createdSignerId)
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
                    try await client.fields.delete(fieldId: createdFieldId)
                } catch let cleanupError {
                    XCTFail("Field cleanup failed: \(cleanupError.localizedDescription)")
                }
            }
            throw error
        }
    }

    /// Verifies the sandbox template CRUD extension, which is intentionally
    /// retained although these four operations are absent from production OpenAPI.
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
            for _ in 0..<30 where fetched.status != "ready" && fetched.status != "failed" {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                fetched = try await client.templates.get(templateId: created.id)
            }
            XCTAssertNotEqual(fetched.status, "failed")

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
                    try await client.templates.delete(templateId: createdTemplateId)
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

            try await client.documents.delete(documentId: uploaded.id)
            createdDocumentId = nil
        } catch {
            if let createdDocumentId {
                do {
                    try await client.documents.delete(documentId: createdDocumentId)
                } catch let cleanupError {
                    XCTFail("Document cleanup failed: \(cleanupError.localizedDescription)")
                }
            }
            throw error
        }
    }

    /// Exercises the end-to-end signature-request path: upload a document,
    /// wait for processing, create signers when needed, estimate the assignment
    /// cost, and create a virtual assignment. Cleans up every resource created
    /// by this test without deleting pre-existing controlled signers.
    func testLiveAssignmentFlow() async throws {
        try requiresMutationOptIn()
        let recipients = try notificationRecipients()
        let baseURL = try credentials().baseURL
        let client = try liveClient()
        let publicClient = AssinafyClient(configuration: AssinafyClientConfiguration(baseURL: baseURL))
        var createdDocumentId: String?
        var createdSignerIds: [String] = []
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
                createdSignerIds.append(signerA.id)
            }

            let signerB: Signer
            if let existingSignerB {
                signerB = existingSignerB
            } else {
                signerB = try await client.signers.create(
                    CreateSignerPayload(fullName: "Live Test Signer B", email: recipients.1)
                )
                createdSignerIds.append(signerB.id)
            }

            let payload = CreateAssignmentPayload.withSignerIds(
                [signerA.id, signerB.id],
                method: .virtual,
                message: "Assinafy iOS SDK live test"
            )

            // Cost estimation should succeed regardless of the account balance.
            _ = try await client.assignments.estimateCost(documentId: uploaded.id, payload: payload)

            let assignment = try await client.assignments.create(
                documentId: uploaded.id,
                payload: payload
            )
            XCTAssertFalse(assignment.id.isEmpty)
            XCTAssertEqual(assignment.method, .virtual)
            XCTAssertEqual(assignment.signers.count, 2)

            let expiresAt = ISO8601DateFormatter().string(
                from: Date(timeIntervalSinceNow: 7 * 24 * 60 * 60)
            )
            let reset = try await client.assignments.resetExpiration(
                documentId: uploaded.id,
                assignmentId: assignment.id,
                expiresAt: expiresAt
            )
            XCTAssertEqual(reset.id, assignment.id)

            let resendCost = try await client.assignments.estimateResendCost(
                documentId: uploaded.id,
                assignmentId: assignment.id,
                signerId: signerA.id
            )
            XCTAssertFalse(resendCost.raw.isEmpty)

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

            let token = try await publicClient.documents.sendPublicSignToken(
                documentId: uploaded.id,
                payload: SendTokenPayload(recipient: recipients.0)
            )
            XCTAssertEqual(token.document.id, uploaded.id)
            XCTAssertEqual(token.channel, "email")
            XCTAssertEqual(token.recipient, recipients.0)

        } catch {
            operationError = error
        }

        var cleanupFailures: [String] = []
        if let createdDocumentId {
            do {
                try await client.documents.delete(documentId: createdDocumentId)
            } catch {
                cleanupFailures.append("document: \(error.localizedDescription)")
            }
        }
        for signerId in createdSignerIds {
            do {
                try await client.signers.delete(signerId: signerId)
            } catch {
                cleanupFailures.append("signer \(signerId): \(error.localizedDescription)")
            }
        }
        XCTAssertTrue(
            cleanupFailures.isEmpty,
            "Assignment-flow cleanup failed: \(cleanupFailures.joined(separator: "; "))"
        )
        if let operationError { throw operationError }
    }
}
