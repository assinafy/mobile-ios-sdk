import Foundation

/// Manages workspace tags and document tag attachments.
///
/// Access this resource through ``AssinafyClient/tags``.
@objcMembers
public final class TagResource: BaseResource, @unchecked Sendable {

    // MARK: - Workspace tags

    /// Lists tags in a workspace.
    ///
    /// Mirrors `GET /accounts/{account_id}/tags`.
    public func list(
        params: TagListParams = TagListParams(),
        accountId: String? = nil
    ) async throws -> PaginatedResult<Tag> {
        let id = try self.accountId(accountId)
        let items = params.toQueryItems()
        return try await callList(
            "Failed to list tags",
            request: .get("/accounts/\(id)/tags", queryItems: items.isEmpty ? nil : items)
        )
    }

    /// Creates a workspace tag.
    ///
    /// Mirrors `POST /accounts/{account_id}/tags`.
    public func create(
        _ payload: CreateTagPayload,
        accountId: String? = nil
    ) async throws -> Tag {
        try validateTagName(payload.name)
        try validateTagColor(payload.color)
        let id = try self.accountId(accountId)
        let request = try APIRequest.post("/accounts/\(id)/tags", body: payload)
        return try await call("Failed to create tag", request: request)
    }

    /// Updates a tag's name and/or color.
    ///
    /// Mirrors `PUT /accounts/{account_id}/tags/{tag_id}`.
    public func update(
        tagId: String,
        payload: UpdateTagPayload,
        accountId: String? = nil
    ) async throws -> Tag {
        let id = try self.accountId(accountId)
        let tid = try requireId(tagId, name: "Tag ID")
        if let name = payload.name {
            try validateTagName(name)
        }
        guard payload.name != nil || payload.color != nil || payload.clearsColor else {
            throw ValidationError("At least one tag field is required")
        }
        try validateTagColor(payload.color)
        let request = try APIRequest.put("/accounts/\(id)/tags/\(tid)", body: payload)
        return try await call("Failed to update tag", request: request)
    }

    /// Deletes a tag.
    ///
    /// Mirrors `DELETE /accounts/{account_id}/tags/{tag_id}`. Pass `force`
    /// to detach the tag from documents/templates before deleting it.
    public func delete(
        tagId: String,
        force: Bool = false,
        accountId: String? = nil
    ) async throws {
        let id = try self.accountId(accountId)
        let tid = try requireId(tagId, name: "Tag ID")
        let items = force ? [URLQueryItem(name: "force", value: "true")] : nil
        try await callVoid(
            "Failed to delete tag",
            request: .delete("/accounts/\(id)/tags/\(tid)", queryItems: items)
        )
    }

    /// Deletes a tag and returns the documented `{ "deleted": boolean }` value.
    public func deleteAndReturnStatus(
        tagId: String,
        force: Bool = false,
        accountId: String? = nil
    ) async throws -> Bool {
        let id = try self.accountId(accountId)
        let tid = try requireId(tagId, name: "Tag ID")
        let items = force ? [URLQueryItem(name: "force", value: "true")] : nil
        let response: TagDeleteResponse = try await call(
            "Failed to delete tag",
            request: .delete("/accounts/\(id)/tags/\(tid)", queryItems: items)
        )
        return response.deleted
    }

    // MARK: - Document tags

    /// Lists tags attached to a document.
    ///
    /// Mirrors `GET /accounts/{account_id}/documents/{document_id}/tags`.
    public func listDocumentTags(
        documentId: String,
        accountId: String? = nil
    ) async throws -> [Tag] {
        let id = try self.accountId(accountId)
        let did = try requireId(documentId, name: "Document ID")
        let result: PaginatedResult<Tag> = try await callList(
            "Failed to list document tags",
            request: .get("/accounts/\(id)/documents/\(did)/tags")
        )
        return result.data
    }

    /// Replaces all tags attached to a document by tag ID.
    ///
    /// Mirrors `PUT /accounts/{account_id}/documents/{document_id}/tags`.
    /// Passing an empty array removes all document tags.
    public func replaceDocumentTags(
        documentId: String,
        tagIds: [String],
        accountId: String? = nil
    ) async throws -> [Tag] {
        try await writeDocumentTags(
            documentId: documentId,
            tagIds: tagIds,
            method: .put,
            allowEmpty: true,
            label: "Failed to replace document tags",
            accountId: accountId
        )
    }

    /// Compatibility overload for the former, incorrectly named `tagNames`
    /// argument. Values have always been tag IDs.
    @available(*, deprecated, renamed: "replaceDocumentTags(documentId:tagIds:accountId:)")
    public func replaceDocumentTags(
        documentId: String,
        tagNames: [String],
        accountId: String? = nil
    ) async throws -> [Tag] {
        try await replaceDocumentTags(documentId: documentId, tagIds: tagNames, accountId: accountId)
    }

    /// Appends tags to a document by tag ID without removing existing tags.
    ///
    /// Mirrors `POST /accounts/{account_id}/documents/{document_id}/tags`.
    public func appendDocumentTags(
        documentId: String,
        tagIds: [String],
        accountId: String? = nil
    ) async throws -> [Tag] {
        try await writeDocumentTags(
            documentId: documentId,
            tagIds: tagIds,
            method: .post,
            allowEmpty: false,
            label: "Failed to append document tags",
            accountId: accountId
        )
    }

    /// Compatibility overload for the former, incorrectly named `tagNames`
    /// argument. Values have always been tag IDs.
    @available(*, deprecated, renamed: "appendDocumentTags(documentId:tagIds:accountId:)")
    public func appendDocumentTags(
        documentId: String,
        tagNames: [String],
        accountId: String? = nil
    ) async throws -> [Tag] {
        try await appendDocumentTags(documentId: documentId, tagIds: tagNames, accountId: accountId)
    }

    /// Detaches one tag from a document without deleting the tag.
    ///
    /// Mirrors `DELETE /accounts/{account_id}/documents/{document_id}/tags/{tag_id}`.
    public func detachDocumentTag(
        documentId: String,
        tagId: String,
        accountId: String? = nil
    ) async throws {
        let id = try self.accountId(accountId)
        let did = try requireId(documentId, name: "Document ID")
        let tid = try requireId(tagId, name: "Tag ID")
        try await callVoid(
            "Failed to detach document tag",
            request: .delete("/accounts/\(id)/documents/\(did)/tags/\(tid)")
        )
    }

    /// Detaches a document tag and returns `{ "detached": boolean }`.
    public func detachDocumentTagAndReturnStatus(
        documentId: String,
        tagId: String,
        accountId: String? = nil
    ) async throws -> Bool {
        let id = try self.accountId(accountId)
        let did = try requireId(documentId, name: "Document ID")
        let tid = try requireId(tagId, name: "Tag ID")
        let response: TagDetachResponse = try await call(
            "Failed to detach document tag",
            request: .delete("/accounts/\(id)/documents/\(did)/tags/\(tid)")
        )
        return response.detached
    }

    // MARK: - Objective-C / completion-handler API

    /// Lists workspace tags and delivers the result on the **main queue**.
    @objc(listTagsWithAccountId:completion:)
    public func list(accountId: String?, completion: @escaping ([Tag]?, Error?) -> Void) {
        withListCompletion({ try await self.list(accountId: accountId) }, completion: completion)
    }

    /// Creates a workspace tag and delivers the result on the **main queue**.
    @objc(createTag:accountId:completion:)
    public func create(
        _ payload: CreateTagPayload,
        accountId: String?,
        completion: @escaping (Tag?, Error?) -> Void
    ) {
        withCompletion({ try await self.create(payload, accountId: accountId) }, completion: completion)
    }

    /// Updates a workspace tag and delivers the result on the **main queue**.
    @objc(updateTagWithId:payload:accountId:completion:)
    public func update(
        tagId: String,
        payload: UpdateTagPayload,
        accountId: String?,
        completion: @escaping (Tag?, Error?) -> Void
    ) {
        withCompletion({ try await self.update(tagId: tagId, payload: payload, accountId: accountId) },
                       completion: completion)
    }

    /// Deletes a workspace tag and notifies the **main queue** upon completion.
    @objc(deleteTagWithId:force:accountId:completion:)
    public func delete(
        tagId: String,
        force: Bool,
        accountId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        withVoidCompletion({ try await self.delete(tagId: tagId, force: force, accountId: accountId) },
                           completion: completion)
    }

    // MARK: - Private

    /// Shared body for the replace (`PUT`) and append (`POST`) document-tag routes,
    /// which differ only in verb and whether an empty list is meaningful.
    ///
    /// The sandbox host answers both with an empty array instead of the updated
    /// tag list, so a follow-up read supplies the documented response there.
    private func writeDocumentTags(
        documentId: String,
        tagIds: [String],
        method: HTTPMethod,
        allowEmpty: Bool,
        label: String,
        accountId: String?
    ) async throws -> [Tag] {
        let id = try self.accountId(accountId)
        let did = try requireId(documentId, name: "Document ID")
        try validateTagIds(tagIds, allowEmpty: allowEmpty)
        let requestValues = try await tagRequestValues(tagIds, accountId: id)
        let request = APIRequest(
            method: method,
            path: "/accounts/\(id)/documents/\(did)/tags",
            body: try JSONEncoder.assinafy.encode(TagNamesPayload(tags: requestValues))
        )
        let result: PaginatedResult<Tag> = try await callList(label, request: request)
        if usesSandboxCompatibility, !tagIds.isEmpty, result.data.isEmpty {
            return try await listDocumentTags(documentId: did, accountId: id)
        }
        return result.data
    }

    private func validateTagName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError("Tag name is required") }
        guard trimmed.count <= 64 else { throw ValidationError("Tag name must be 64 characters or fewer") }
    }

    private func validateTagIds(_ ids: [String], allowEmpty: Bool) throws {
        if ids.isEmpty, !allowEmpty {
            throw ValidationError("At least one tag ID is required")
        }
        for id in ids {
            _ = try requireId(id, name: "Tag ID")
        }
    }

    private func validateTagColor(_ color: String?) throws {
        guard let color else { return }
        guard color.range(of: "^#?[0-9A-Fa-f]{6}$", options: .regularExpression)
                == color.startIndex..<color.endIndex else {
            throw ValidationError("Tag color must be a 6-character hexadecimal value")
        }
    }

    private func tagRequestValues(_ tagIds: [String], accountId: String) async throws -> [String] {
        guard usesSandboxCompatibility, !tagIds.isEmpty else { return tagIds }
        let requestedIds = Set(tagIds)
        var namesById: [String: String] = [:]
        var page = 1
        while true {
            let tags: PaginatedResult<Tag> = try await callList(
                "Failed to resolve sandbox tag IDs",
                request: .get(
                    "/accounts/\(accountId)/tags",
                    queryItems: [
                        URLQueryItem(name: "page", value: String(page)),
                        URLQueryItem(name: "per-page", value: "100"),
                    ]
                )
            )
            for tag in tags.data where requestedIds.contains(tag.id) {
                namesById[tag.id] = tag.name
            }
            if requestedIds.isSubset(of: namesById.keys) { break }
            if let lastPage = tags.meta?.lastPage, page < lastPage {
                page += 1
                continue
            }
            if tags.meta == nil, tags.data.count == 100 {
                throw AssinafySDKError("Sandbox tag catalog omitted pagination metadata")
            }
            break
        }
        return try tagIds.map { tagId in
            guard let name = namesById[tagId] else {
                throw ValidationError("One or more tag IDs do not exist in the sandbox workspace")
            }
            return name
        }
    }
}
