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
        // Sandbox keys only authenticate against the sandbox host, so allow the
        // base URL to be overridden (e.g. https://sandbox.assinafy.com.br/v1).
        let baseURL = env["ASSINAFY_BASE_URL"].flatMap { $0.isEmpty ? nil : $0 }
            ?? AssinafyClientConfiguration.productionBaseURL
        return LiveCredentials(apiKey: apiKey, accountId: accountId, baseURL: baseURL)
    }

    private func liveClient() throws -> AssinafyClient {
        let creds = try credentials()
        return AssinafyClient(apiKey: creds.apiKey, defaultAccountId: creds.accountId, baseURL: creds.baseURL)
    }

    private func uniqueName(_ prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.prefix(8))"
    }

    private func requiresDocumentMutationOptIn() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["ASSINAFY_RUN_DOCUMENT_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Set ASSINAFY_RUN_DOCUMENT_LIVE_TESTS=1 to run document upload/delete live tests.")
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

    /// Uploads a document, renames it via `PATCH /documents/{id}`, and cleans up.
    func testLiveDocumentRename() async throws {
        try requiresDocumentMutationOptIn()
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
                try? await client.documents.delete(documentId: createdDocumentId)
            }
            throw error
        }
    }

    func testLiveTagCrud() async throws {
        let client = try liveClient()
        let tagName = uniqueName("codex-sdk-audit")
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
                try? await client.tags.delete(tagId: createdTagId, force: true)
            }
            throw error
        }
    }

    func testLiveSignerCrud() async throws {
        let client = try liveClient()
        let localPart = uniqueName("codex-sdk-audit")
        let email = "\(localPart)@example.com"
        var createdSignerId: String?

        do {
            let created = try await client.signers.create(
                CreateSignerPayload(fullName: "Codex SDK Audit", email: email)
            )
            createdSignerId = created.id
            XCTAssertEqual(created.email?.lowercased(), email.lowercased())

            let fetched = try await client.signers.get(signerId: created.id)
            XCTAssertEqual(fetched.id, created.id)

            let updated = try await client.signers.update(
                signerId: created.id,
                payload: UpdateSignerPayload(fullName: "Codex SDK Audit Updated")
            )
            XCTAssertEqual(updated.fullName, "Codex SDK Audit Updated")

            try await client.signers.delete(signerId: created.id)
            createdSignerId = nil
        } catch {
            if let createdSignerId {
                try? await client.signers.delete(signerId: createdSignerId)
            }
            throw error
        }
    }

    func testLiveDocumentUploadGetDownloadDelete() async throws {
        try requiresDocumentMutationOptIn()
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
                try? await client.documents.delete(documentId: createdDocumentId)
            }
            throw error
        }
    }

    /// Exercises the end-to-end signature-request path: upload a document,
    /// wait for processing, create signers, estimate the assignment cost, and
    /// create a virtual assignment. Cleans up the document afterwards.
    func testLiveAssignmentFlow() async throws {
        try requiresDocumentMutationOptIn()
        let client = try liveClient()
        var createdDocumentId: String?

        do {
            let uploaded = try await client.documents.upload(minimalPDF())
            createdDocumentId = uploaded.id
            _ = try await client.documents.waitUntilReady(
                documentId: uploaded.id,
                options: WaitUntilReadyOptions(maxWaitSeconds: 60, pollIntervalSeconds: 2)
            )

            // `create` is idempotent by email, so reusing the audit signers is safe.
            let signerA = try await client.signers.create(
                CreateSignerPayload(fullName: "Audit Signer A", email: "bill@febacapital.com")
            )
            let signerB = try await client.signers.create(
                CreateSignerPayload(fullName: "Audit Signer B", email: "billm@billm.org")
            )

            let payload = CreateAssignmentPayload.withSignerIds(
                [signerA.id, signerB.id],
                method: .virtual,
                message: "Assinafy iOS SDK live audit"
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

            try await client.documents.delete(documentId: uploaded.id)
            createdDocumentId = nil
        } catch {
            if let createdDocumentId {
                try? await client.documents.delete(documentId: createdDocumentId)
            }
            throw error
        }
    }
}
