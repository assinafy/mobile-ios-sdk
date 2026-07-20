# Assinafy iOS SDK — API Reference

Full request/response reference for every public method in the SDK, mapped to the
OpenAPI/Scalar reference at <https://api.assinafy.com.br/v1/docs> (backed by
<https://api.assinafy.com.br/v1/docs/openapi.json>). Response samples are
real payloads captured from the sandbox API (`https://sandbox.assinafy.com.br/v1`);
long arrays are trimmed with `…` and identifiers are illustrative.

## Conventions

**Response envelope.** Every JSON endpoint wraps its result in a status envelope:

```json
{ "status": 200, "message": "", "data": <payload-or-array> }
```

The SDK unwraps `data` automatically and surfaces typed models. Non-2xx envelopes
(or transport-level non-2xx codes) are thrown as ``APIError`` carrying `statusCode`,
`message`, and the raw `responseData`.

**Authentication.** Construct the client with either an API key (`X-Api-Key`) or a
bearer token (`Authorization: Bearer …`):

```swift
let client = AssinafyClient(apiKey: "…", defaultAccountId: "102d…45fd")
// or
let client = AssinafyClient(token: "…")
```

`baseURL` defaults to `https://api.assinafy.com.br/v1`; pass a different value to
target the sandbox.

**Pagination.** List methods return `PaginatedResult<T>` (`.data` + `.meta`).
`meta` is read from `X-Pagination-Current-Page`, `X-Pagination-Per-Page`,
`X-Pagination-Total-Count`, and `X-Pagination-Page-Count`. Common query params:
`page`, `per-page` (max 100), `search`, `sort` (e.g. `name`, `-created_at`).

**Errors.** `ValidationError` (client-side, before any request), `APIError`
(non-2xx HTTP), `NetworkError` (transport failure), `AssinafySDKError` (other).

---

## `client.auth`

Login and password-reset calls require no credentials. API-key endpoints operate on
the bearer-authenticated user.

### `login(_:) -> LoginResponse`
`POST /login`

Request:
```json
{ "email": "user@example.com", "password": "••••••••" }
```
Response (`data`):
```json
{
  "access_token": "eyJ0eXAiOiJKV1Qi…",
  "user": {
    "id": "60f7…", "name": "Bill M", "email": "user@example.com",
    "telephone": null, "government_id": null,
    "is_email_verified": true, "has_accepted_terms": true,
    "created_at": "2026-05-12T18:05:11Z", "to_be_deleted_at": null
  },
  "accounts": [
    { "id": "102d…45fd", "name": "MT", "roles": ["owner"],
      "is_delete_allowed": true, "created_at": "2026-05-12T18:05:11Z" }
  ]
}
```

### `socialLogin(_:) -> LoginResponse`
`POST /authentication/social-login`

Request:
```json
{ "provider": "google", "token": "<oauth-id-token>", "has_accepted_terms": true }
```
Response: same shape as `login`.

### `changePassword(_:)`
`PUT /authentication/change-password` — returns no body.

Request:
```json
{ "email": "user@example.com", "password": "current", "new_password": "next" }
```

### `requestPasswordReset(_:)`
`PUT /authentication/request-password-reset` — returns no body.

Request: `{ "email": "user@example.com" }`

### `resetPassword(_:)`
`PUT /authentication/reset-password` — returns no body.

Request:
```json
{ "email": "user@example.com", "token": "<emailed-token>", "new_password": "next" }
```

### `getAPIKey() -> String?`
`GET /users/api-keys`

Response (`data`): `{ "api_key": "8mzG…masked…q" }` → returns the masked key, or `nil`.

### `createAPIKey(_:) -> String`
`POST /users/api-keys`

Request: `{ "password": "••••••••" }`
Response (`data`): `{ "api_key": "8mzGm_F8K2m6…full-key…" }` → returns the new key.

### `deleteAPIKey()`
`DELETE /users/api-keys` — returns no body.

### `currentUser() -> SelfResponse`
`GET /users/self`

Response (`data`):
```json
{
  "user": { "id": "md3j…", "name": "Multica Test", "email": "bill@febacapital.com",
    "telephone": null, "government_id": "", "is_email_verified": true,
    "has_accepted_terms": true, "is_password_set": true,
    "created_at": "2026-05-12T18:05:11Z", "to_be_deleted_at": null },
  "accounts": [ { "id": "102d…45fd", "name": "MT", "roles": ["owner"],
    "is_delete_allowed": true, "created_at": "2026-05-12T18:05:11Z" } ]
}
```

### `stats(params:) -> [DocumentStatsRow]`
`GET /users/self/stats` — production-only; returns `404` on the sandbox host. Query
params: `granularity` (`monthly` default / `daily`), `month` (`YYYY-MM`, required for
daily).

Response (`data`): array of `DocumentStatsRow`:
```json
{ "period": "2026-06", "documents_uploaded": 42, "documents_sent": 37,
  "signature_requests": 61, "signature_requests_email": 55,
  "signature_requests_whatsapp": 18, "documents_opened": 44,
  "documents_signed": 52, "documents_certified": 30 }
```

### `linkSocialLogin(_:)`
`POST /auth/link-social-login`

Request: `{ "provider": "google", "token": "ya29…" }` — returns `{status, message}` only.

### `socialLoginAuthorizationURL(authClient:) -> URL?`
Builds the `GET /auth/authenticate?authclient=google` browser URL for social login
(`AssinafyClient.socialLoginAuthorizationURL(authClient:)`).

---

## `client.workspaces`

Account-management endpoints. (Not listed in the public docs page, but live and
stable on the API — verified against the sandbox.)

### `create(_:) -> WorkspaceResponse`
`POST /accounts`

Request (`notification_sender_type` ∈ `User` / `Account`):
```json
{ "name": "Acme Corp", "notification_sender_type": "Account" }
```
Response (`data`):
```json
{ "id": "102d…45fd", "name": "Acme Corp", "primary_color": null,
  "secondary_color": null, "created_at": "2026-05-12T18:05:11Z" }
```

### `list(params:) -> PaginatedResult<WorkspaceListItem>`
`GET /accounts`

Response (`data`):
```json
[
  { "id": "102d…45fd", "name": "MT", "roles": ["owner"],
    "is_delete_allowed": true, "created_at": "2026-05-12T18:05:11Z" }
]
```

### `get(workspaceId:) -> WorkspaceResponse`
`GET /accounts/{id}`

Response (`data`):
```json
{ "id": "102d…45fd", "name": "MT", "primary_color": null,
  "secondary_color": null, "created_at": "2026-05-12T18:05:11Z" }
```

### `update(workspaceId:payload:) -> WorkspaceResponse`
`PUT /accounts/{id}` — body `{ "name": "New", "notification_sender_type": "User" }`
(non-nil subset). Response as `get`.

### `delete(workspaceId:force:)`
`DELETE /accounts/{id}` — irreversible; sends `{ "force": true }` body. Returns no body.

### `theme(accountId:) -> AccountTheme`
`GET /accounts/{id}/theme`

Response (`data`):
```json
{ "account_name": "MT", "primary_color": "2072b9", "secondary_color": "ffffff", "logo": null }
```
The canonical source of branding colours.

### `stats(params:accountId:) -> [DocumentStatsRow]`
`GET /accounts/{id}/stats` — production-only (`404` on sandbox). Same `DocumentStatsRow`
shape and query params (`granularity`, `month`) as `auth.stats`.

### `downloadLogo(accountId:) -> Data`
`GET /accounts/{id}/logo` — returns raw image bytes (`404` when no logo set).

### `uploadLogo(_:filename:contentType:accountId:)`
`POST /accounts/{id}/logo` — `multipart/form-data`, part `file`. Returns `{status, message}`.

### `deleteLogo(accountId:)`
`DELETE /accounts/{id}/logo` — returns no body.

---

## `client.signers`

`create` is idempotent by email: it searches first and reuses an existing signer
(and also recovers from a `409` race).

### `create(_:accountId:) -> Signer`
`POST /accounts/{account_id}/signers`

Request (`email` **or** `whatsapp_phone_number` required):
```json
{ "full_name": "John Doe", "email": "john@example.com",
  "whatsapp_phone_number": "+5548999990000" }
```
Response (`data`):
```json
{ "resource": "signer", "id": "19e6…d8c", "full_name": "John Doe",
  "email": "john@example.com", "whatsapp_phone_number": null,
  "has_accepted_terms": false }
```

### `get(signerId:accountId:) -> Signer`
`GET /accounts/{account_id}/signers/{signer_id}`

Response (`data`):
```json
{ "resource": "signer", "id": "19e6…d8c", "full_name": "Bill M",
  "email": "bill@febacapital.com", "whatsapp_phone_number": null,
  "has_accepted_terms": false }
```

### `list(params:accountId:) -> PaginatedResult<Signer>`
`GET /accounts/{account_id}/signers` — `search` filters by name or email.

Response (`data`): array of the signer object above.

### `update(signerId:payload:accountId:) -> Signer`
`PUT /accounts/{account_id}/signers/{signer_id}` — body is the non-nil subset of
`full_name`/`email`/`whatsapp_phone_number`. Response: the updated `Signer`.

### `delete(signerId:accountId:)`
`DELETE /accounts/{account_id}/signers/{signer_id}` — returns no body.

### `findByEmail(_:accountId:) -> Signer?`
Convenience over `list` (`per-page=100`, `search=<email>`); case-insensitive match. `404` → `nil`.

### `getSelf(signerAccessCode:) -> SignerSelfInfo`
`GET /signers/self?signer-access-code={code}`

Response (`data`):
```json
{ "id": "19e6…d8c", "full_name": "Bill M", "email": "bill@febacapital.com",
  "whatsapp_phone_number": null, "has_accepted_terms": false,
  "has_signature": false, "has_initial": false }
```

### `acceptTerms(signerAccessCode:) -> AcceptTermsResponse`
`PUT /signers/accept-terms`

Request: `{ "signer-access-code": "<code>" }`
Response (`data`): `{ "full_name": "Bill M", "email": "…", "has_accepted_terms": true }`

### `verifyEmail(payload:)`
`POST /verify` — returns no body.

Request: `{ "verification-code": "123456", "signer-access-code": "<code>" }`

### `uploadSignature(signerAccessCode:type:imageData:reuse:)`
`POST /signature?signer-access-code={code}&type={signature|initial}` — raw PNG/JPEG body (`Content-Type: image/png`); returns no body. Optional `reuse=true` query flag.

### `downloadSignature(signerAccessCode:type:) -> Data`
`GET /signature/{type}?signer-access-code={code}` — returns raw image bytes.

### `getCurrentDocument(signerId:signerAccessCode:) -> DocumentDetails`
`GET /signers/{signer_id}/document?signer-access-code={code}` — the signer's active document (see `documents.get` shape; `assignment.items` is filtered to this signer).

### `listSignerDocuments(signerId:signerAccessCode:params:) -> PaginatedResult<DocumentDetails>`
`GET /signers/{signer_id}/documents?signer-access-code={code}` — filters: `status`, `method`, `search`, `sort`.

### `searchSignerDocuments(signerId:signerAccessCode:search:status:) -> PaginatedResult<DocumentDetails>`
`GET /signers/{signer_id}/documents/search?signer-access-code={code}` — query `search`, `status`.

### `signMultipleDocuments(signerAccessCode:documentIds:)`
`PUT /signers/documents/sign-multiple?signer-access-code={code}` — returns no body.

Request: `{ "document_ids": ["doc1", "doc2"] }`

### `declineMultipleDocuments(signerAccessCode:documentIds:reason:)`
`PUT /signers/documents/decline-multiple?signer-access-code={code}` — returns no body.

Request: `{ "document_ids": ["doc1"], "decline_reason": "Not my contract" }`

### `downloadSignerDocumentArtifact(signerId:documentId:artifact:signerAccessCode:) -> Data`
`GET /signers/{signer_id}/documents/{document_id}/download/{artifact}?signer-access-code={code}` — raw bytes.

### `getSigningDocument(signerAccessCode:hasAcceptedTerms:) -> DocumentDetails`
`GET /sign?signer-access-code={code}[&has_accepted_terms=…]` — resolves a signing document from an access code alone.

---

## `client.documents`

### `upload(_:options:) -> DocumentUploadResponse`
`POST /accounts/{account_id}/documents` — `multipart/form-data`, part `file` = PDF
bytes. Client-side checks: PDF magic bytes + ≤ 25 MB.

Response (`data`):
```json
{
  "id": "19e6…df", "account_id": "102d…45fd", "template_id": null,
  "name": "document.pdf", "status": "uploading",
  "artifacts": { "original": "https://…/documents/19e6…df/download/original",
                 "thumbnail": "https://…/documents/19e6…df/thumbnail" },
  "pages": [], "tags": [], "is_closed": false,
  "decline_reason": null, "declined_by": null,
  "created_at": "2026-05-28T14:22:18Z", "updated_at": "2026-05-28T14:22:18Z"
}
```

### `list(params:accountId:) -> PaginatedResult<DocumentListItem>`
`GET /accounts/{account_id}/documents`. Two overloads: `ListParams` (page/per-page/
search/sort) or `DocumentListParams` (adds `status`, `method`, `tags` (comma-joined ids)).

Response (`data`): array of documents shaped like `get` below (with embedded `assignment`).

### `get(documentId:) -> DocumentDetails`
`GET /documents/{document_id}`

Response (`data`):
```json
{
  "id": "19e6…df", "account_id": "102d…45fd", "name": "cs-assign.pdf",
  "status": "pending_signature", "signing_url": "https://app…/sign/19e6…df",
  "artifacts": { "original": "…", "thumbnail": "…" },
  "pages": [ { "id": "…", "number": 1, "height": 842, "width": 595,
              "download_url": "…" } ],
  "tags": [], "is_closed": false, "decline_reason": null, "declined_by": null,
  "assignment": {
    "id": "1030…7ac", "sender_email": "bill@febacapital.com", "method": "virtual",
    "expires_at": null, "message": "chat-sdk live integration test",
    "signers": [ { "id": "19e6…d8c", "full_name": "Bill M",
                   "email": "bill@febacapital.com", "whatsapp_phone_number": null,
                   "has_accepted_terms": false, "completed": false,
                   "verification_method": "Email", "notification_methods": ["Email"],
                   "step": 1, "notified": true, "notification_history": [] } ],
    "copy_receivers": [], "items": [], "summary": null, "signing_urls": []
  },
  "created_at": "2026-05-28T14:22:18Z", "updated_at": "2026-06-05T16:18:29Z"
}
```

> Note: the API returns `"method": null` for collect assignments and may use the
> key `expiration` instead of `expires_at`; the SDK decodes both safely.

### `rename(documentId:name:) -> DocumentDetails`
`PATCH /documents/{document_id}`

Request: `{ "name": "renamed.pdf" }`. Returns the updated `DocumentDetails`.

### `search(search:status:accountId:) -> PaginatedResult<DocumentListItem>`
`GET /accounts/{account_id}/documents/search` — query `search`, `status`. Lightweight
list; items match `DocumentListItem` (now includes `signing_url`).

### `waitUntilReady(documentId:options:) -> DocumentUploadResponse`
Polls `GET /documents/{document_id}` until status is one of `metadata_ready`,
`pending_signature`, `certificating`, `certificated` (or throws on `failed`/timeout).
`WaitUntilReadyOptions(maxWaitSeconds:pollIntervalSeconds:)` default 30 s / 2 s.

### `downloadArtifact(documentId:artifact:) -> Data`
`GET /documents/{document_id}/download/{artifact}` — artifact ∈ `original`,
`certificated`, `certificate-page`, `bundle`. Returns raw bytes.

### `downloadThumbnail(documentId:) -> Data`
`GET /documents/{document_id}/thumbnail` — raw image bytes.

### `downloadPage(documentId:pageId:) -> Data`
`GET /documents/{document_id}/pages/{page_id}/download` — raw JPEG bytes.

### `activities(documentId:) -> [DocumentActivity]`
`GET /documents/{document_id}/activities`

Response (`data`):
```json
[ { "id": 1, "event": "document.uploaded",
    "message": "Document uploaded", "origin": null,
    "payload": { "user_name": "Bill M", "user_email": "…" },
    "created_at": "2026-05-28T14:22:18Z" } ]
```
(`origin`/`payload` may be objects; they are surfaced as JSON strings.)

### `delete(documentId:)`
`DELETE /documents/{document_id}` — returns no body. Only allowed for statuses the
API marks deletable (see `listStatuses`); deleting during `metadata_processing`
returns `400`.

### `createFromTemplate(templateId:signers:options:accountId:) -> DocumentUploadResponse`
`POST /accounts/{account_id}/templates/{template_id}/documents`

Request:
```json
{
  "signers": [ { "role_id": "r1", "id": "19e6…d8c",
                 "verification_method": "email",
                 "notification_methods": ["email"], "step": 1 } ],
  "name": "Service Agreement", "message": "Please sign",
  "expires_at": "2026-12-31T23:59:59Z",
  "editor_fields": [ { "field_id": "f1", "value": "Acme" } ],
  "tags": ["contracts"]
}
```
Response: same as `upload`.

### `estimateCostFromTemplate(templateId:signers:accountId:) -> CostEstimate`
`POST /accounts/{account_id}/templates/{template_id}/documents/estimate-cost`

Request: `{ "signers": [ { "role_id": "r1", "verification_method": "email" } ] }`
Response (`data`) — fields vary by plan; all preserved in `CostEstimate.raw`:
```json
{ "credit_balance": 100, "document_balance": 5, "estimated_cost": 1,
  "needs_extra_document": false, "extra_document_cost": 0,
  "total_credits": 1, "has_sufficient_resources": true,
  "blocking_reason": null, "message": null }
```

### `verify(signatureHash:) -> Bool`
`GET /documents/{signature_hash}/verify`

Response (`data`): `{ "is_valid": true }` (also accepts `{ "verified": true }`).

### `isFullySigned(documentId:) -> Bool`
Convenience: fetches `get` and compares `assignment.summary.completed_count` to `signer_count`.

### `getSigningProgress(documentId:) -> SigningProgress`
Convenience: derives `signed`/`total`/`pending`/`percentage` from `assignment.summary`.

### `listStatuses() -> [DocumentStatusInfo]`
`GET /documents/statuses`

Response (`data`):
```json
[ { "code": "uploading", "deletable": false },
  { "code": "metadata_ready", "deletable": true },
  { "code": "pending_signature", "deletable": true },
  { "code": "certificated", "deletable": false }, … ]
```

### `getPublicInfo(documentId:) -> PublicDocumentInfo`
`GET /public/documents/{document_id}` — no auth.

Response (`data`): `{ "id": "…", "name": "…", "page_count": "1", "created_by": "Acme" }`

### `sendPublicSignToken(documentId:payload:) -> SendTokenResponse`
`PUT /public/documents/{document_id}/send-token` — no auth.

Request: `{ "email": "someone@example.com" }` (documented field). For the WhatsApp
channel the SDK additionally sends `"channel": "whatsapp"`. (Previously sent
`recipient`/`channel`.)
Response (`data`): `{ "document": { … }, "channel": "email", "recipient": "…" }`

### `confirmSignerData(documentId:signerAccessCode:payload:)`
`PUT /documents/{document_id}/signers/confirm-data?signer-access-code={code}` — returns no body. Required before signing a virtual assignment.

Request:
```json
{ "email": "user@example.com", "whatsapp_phone_number": null, "has_accepted_terms": true }
```
The payload also supports the documented `full_name` and `government_id` fields.

---

## `client.assignments`

### `list(params:accountId:) -> PaginatedResult<Assignment>`
`GET /assignments` — the account context is supplied via the `accountId` query
parameter (camelCase; required — the API returns `400` without it). Query also accepts
`page`, `per-page`.

Response (`data`): array of `Assignment` objects:
```json
{ "id": "…", "sender_email": "bill@febacapital.com", "method": "virtual",
  "expires_at": null, "message": "…",
  "signers": [ { "id": "…", "full_name": "…", "email": "…",
                 "whatsapp_phone_number": null, "has_accepted_terms": false,
                 "completed": false, "verification_method": "Email",
                 "notification_methods": ["Email"], "step": 1, "notified": true } ],
  "copy_receivers": [], "items": [ … ] }
```

### `create(documentId:payload:) -> Assignment`
`POST /documents/{document_id}/assignments`

Request (virtual):
```json
{ "method": "virtual",
  "signers": [ { "id": "19e6…d8c" } ],
  "message": "Please sign", "expires_at": "2026-12-31T23:59:59Z",
  "copy_receivers": ["103…2c79"] }
```
Request (collect adds page/field entries):
```json
{ "method": "collect",
  "signers": [ { "id": "19e6…d8c" } ],
  "entries": [ { "page_id": "p1",
                 "fields": [ { "signer_id": "19e6…d8c", "field_id": "f1",
                               "display_settings": "{…}" } ] } ] }
```
Response (`data`): the `assignment` object shown under `documents.get`.

Per-signer `step` (1-based ordered signing) is supported via
`SignerReference.descriptor(..., step:)`.

### `estimateCost(documentId:payload:) -> CostEstimate`
`POST /documents/{document_id}/assignments/estimate-cost` — same body as `create`
(signer IDs optional for estimation). Response: `CostEstimate` (see template estimate).

### `resetExpiration(documentId:assignmentId:expiresAt:) -> Assignment`
`PUT /documents/{document_id}/assignments/{assignment_id}/reset-expiration`

Request: `{ "expires_at": "2026-12-31T23:59:59Z" }` (or `null` to clear).

### `resendNotification(documentId:assignmentId:signerId:) -> ResendNotificationResponse`
`PUT /documents/{document_id}/assignments/{assignment_id}/signers/{signer_id}/resend`

Response (`data`): `{ "is_sent": true, "document_id": "…", "signer_id": "…" }`

### `estimateResendCost(documentId:assignmentId:signerId:) -> CostEstimate`
`POST /documents/{document_id}/assignments/{assignment_id}/signers/{signer_id}/estimate-resend-cost`

### `sign(documentId:assignmentId:signerAccessCode:fields:)`
`POST /documents/{document_id}/assignments/{assignment_id}?signer-access-code={code}` — returns no body. Body is an array of signed fields (empty for virtual without inputs):

```json
[ { "itemId": "i1", "fieldId": "f1", "pageId": "p1", "value": "Signed" } ]
```

### `decline(documentId:assignmentId:signerAccessCode:reason:)`
`PUT /documents/{document_id}/assignments/{assignment_id}/reject?signer-access-code={code}` — returns no body. Request: `{ "decline_reason": "…" }`

### `listWhatsappNotifications(documentId:assignmentId:) -> [WhatsappNotification]`
`GET /documents/{document_id}/assignments/{assignment_id}/whatsapp-notifications`

Response (`data`):
```json
[ { "sent_at": 1717000000, "header": "…", "body": "…",
    "buttons": [ { "text": "Sign now" } ],
    "phone_number": "+5548…", "signer_id": "…" } ]
```

---

## `client.templates`

### `create(name:pdfData:accountId:) -> TemplateDetails`
`POST /accounts/{account_id}/templates` — `multipart/form-data` with parts `name`
and `file` (PDF). Same PDF validation as document upload. Response: see `get`.

### `update(templateId:payload:accountId:) -> TemplateDetails`
`PUT /accounts/{account_id}/templates/{template_id}` — body is the non-nil subset of
`name`/`document_name`/`message`.

### `delete(templateId:accountId:)`
`DELETE /accounts/{account_id}/templates/{template_id}` — returns no body. Rejected when documents are linked.

### `list(params:accountId:) -> PaginatedResult<TemplateListItem>`
`GET /accounts/{account_id}/templates`. Overloads: `ListParams` or `TemplateListParams`
(`status`, `search`, `tags`, `sort`). Response (`data`): array of templates.

### `get(templateId:accountId:) -> TemplateDetails`
`GET /accounts/{account_id}/templates/{template_id}`

Response (`data`):
```json
{
  "id": "tpl1", "name": "NDA", "status": "ready", "account_id": "102d…45fd",
  "document_name": "NDA", "message": "Please sign",
  "roles": [ { "id": "r1", "name": "Signer", "assignment_type": "virtual" } ],
  "pages": [ { "id": "p1", "number": 1, "height": 842, "width": 595,
              "download_url": "…",
              "fields": [ { "id": "tf1", "field_id": "f1", "role_id": "r1",
                            "label": "Name", "display_settings": "{…}" } ] } ],
  "tags": [], "default_document_tags": [],
  "created_at": "2026-05-12T18:05:11Z", "updated_at": "2026-05-12T18:05:11Z"
}
```

---

## `client.tags`

### `list(params:accountId:) -> PaginatedResult<Tag>`
`GET /accounts/{account_id}/tags` — optional `search`.

Response (`data`):
```json
[ { "id": "1031…17f4", "name": "audit-doc-tag", "color": null,
    "created_at": "2026-06-05T16:33:35Z", "updated_at": "2026-06-05T16:33:35Z" } ]
```

### `create(_:accountId:) -> Tag`
`POST /accounts/{account_id}/tags`

Request: `{ "name": "contracts", "color": "3366FF" }`
Response (`data`):
```json
{ "resource": "tag", "id": "1031…70f5", "name": "contracts", "color": "3366FF",
  "created_at": "2026-06-05T20:04:16Z", "updated_at": "2026-06-05T20:04:16Z" }
```

### `update(tagId:payload:accountId:) -> Tag`
`PUT /accounts/{account_id}/tags/{tag_id}` — `name` and/or `color`. Pass
`UpdateTagPayload(clearsColor: true)` to send `"color": null`.

### `delete(tagId:force:accountId:)`
`DELETE /accounts/{account_id}/tags/{tag_id}[?force=true]` — `force` detaches from
documents/templates first. Returns no body.

### `listDocumentTags(documentId:accountId:) -> [Tag]`
`GET /accounts/{account_id}/documents/{document_id}/tags`

### `replaceDocumentTags(documentId:tagNames:accountId:) -> [Tag]`
`PUT /accounts/{account_id}/documents/{document_id}/tags` — `{ "tags": ["a","b"] }`
(empty array clears all). Returns the resulting tag set.

### `appendDocumentTags(documentId:tagNames:accountId:) -> [Tag]`
`POST /accounts/{account_id}/documents/{document_id}/tags` — `{ "tags": ["c"] }`.

### `detachDocumentTag(documentId:tagId:accountId:)`
`DELETE /accounts/{account_id}/documents/{document_id}/tags/{tag_id}` — returns no body.

---

## `client.fields`

### `create(_:accountId:) -> FieldDefinition`
`POST /accounts/{account_id}/fields`

Request:
```json
{ "type": "text", "name": "Job title", "regex": null,
  "is_required": true, "is_active": true }
```
Response (`data`):
```json
{ "resource": "field_definition", "id": "1031…2654", "name": "Job title",
  "type": "text", "regex": null, "is_pre_defined": false, "is_active": true,
  "is_required": true, "is_standard": false, "is_read_only": false,
  "is_visible": true }
```

### `list(params:accountId:) -> PaginatedResult<FieldDefinition>`
`GET /accounts/{account_id}/fields` — `FieldListParams(includeInactive:includeStandard:)`
→ `include_inactive` / `include_standard`. Response (`data`): array of field definitions.

### `get(fieldId:accountId:) -> FieldDefinition`
`GET /accounts/{account_id}/fields/{field_id}` — single field definition.

### `update(fieldId:payload:accountId:) -> FieldDefinition`
`PUT /accounts/{account_id}/fields/{field_id}` — non-nil subset of
`type`/`name`/`regex`/`is_required`/`is_active`.

### `delete(fieldId:accountId:)`
`DELETE /accounts/{account_id}/fields/{field_id}` — returns no body. Fields used in a signed document cannot be deleted.

### `validate(fieldId:value:signerAccessCode:accountId:) -> FieldValidationResult`
`POST /accounts/{account_id}/fields/{field_id}/validate[?signer-access-code={code}]`

Request: `{ "value": "11144477735" }`
Response (`data`): `{ "type": "cpf", "success": true, "error_message": "" }`

### `validateMultiple(items:signerAccessCode:accountId:) -> [FieldValidationResult]`
`POST /accounts/{account_id}/fields/validate-multiple[?signer-access-code={code}]`

Request: `[ { "field_id": "f1", "value": "11144477735" } ]`
Response (`data`): array of validation results.

### `listFieldTypes() -> [FieldTypeInfo]`
`GET /field-types`

Response (`data`):
```json
[ { "type": "personName", "name": "Nome" }, { "type": "cpf", "name": "CPF" },
  { "type": "email", "name": "E-mail" }, { "type": "text", "name": "Texto" },
  { "type": "number", "name": "Número" }, { "type": "date", "name": "Data" }, … ]
```

---

## `client.webhooks`

### `register(_:accountId:) -> WebhookSubscription`
`PUT /accounts/{account_id}/webhooks/subscriptions`

Request:
```json
{ "events": ["document_ready", "document_prepared"], "is_active": true,
  "url": "https://example.com/hook", "email": "ops@example.com" }
```
Response (`data`):
```json
{ "events": ["document_ready", "document_prepared"], "is_active": true,
  "url": "https://example.com/hook", "email": "ops@example.com",
  "updated_at": "2026-06-05T18:43:14Z" }
```

### `get(accountId:) -> WebhookSubscription`
`GET /accounts/{account_id}/webhooks/subscriptions` — `data` is an **object** (above).

### `delete(accountId:)` — **DEPRECATED**
The API has no `DELETE` for subscriptions; this now forwards to `inactivate()`
(`PUT /accounts/{account_id}/webhooks/inactivate`). Use `inactivate` instead.

### `inactivate(accountId:)`
`PUT /accounts/{account_id}/webhooks/inactivate` — disables delivery without deleting.

### `listEventTypes() -> [WebhookEventTypeInfo]`
`GET /webhooks/event-types`

Response (`data`):
```json
[ { "id": "document_uploaded", "description": "Triggered when the User has uploaded a Document" },
  { "id": "assignment_created", "description": "…" }, … ]
```

### `listDispatches(params:accountId:) -> PaginatedResult<WebhookDispatch>`
`GET /accounts/{account_id}/webhooks` — `WebhookDispatchListParams` →
`page`, `per-page`, `event`, `delivered`, `from`, `to`.

Response (`data`):
```json
[ { "id": "d1", "event": "document_ready", "activity_id": 42,
    "endpoint": "https://example.com/hook", "delivered": true,
    "http_status": 200, "response_body": "ok", "error": null,
    "created_at": "2026-07-20T19:03:13Z", "updated_at": "2026-07-20T19:03:13Z" } ]
```
`WebhookDispatch.created_at`/`updated_at` are ISO-8601 strings.

### `retryDispatch(dispatchId:accountId:) -> WebhookDispatch`
`POST /accounts/{account_id}/webhooks/{dispatch_id}/retry` — re-delivers; returns the updated dispatch.

---

## High-level helper

### `client.uploadAndRequestSignatures(documentData:options:accountId:)`
Composes: `documents.upload` → `documents.waitUntilReady` → `signers.create` (per
signer, concurrently, idempotent by email) → `assignments.create` (virtual).
Returns `(document: DocumentUploadResponse, assignment: Assignment)`.

```swift
let opts = AssinafyClient.UploadOptions(signers: [
    .init(name: "Bill M", email: "bill@febacapital.com"),
])
opts.message = "Please sign"
let (doc, assignment) = try await client.uploadAndRequestSignatures(
    documentData: pdfData, options: opts)
```
