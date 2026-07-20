# Changelog

## [1.3.0] - 2026-07-20

Full audit against the current OpenAPI spec (`https://api.assinafy.com.br/v1/docs/openapi.json`,
now a Scalar/OpenAPI reference) with every change verified against the live sandbox.

### Added — new endpoint coverage
- **`client.documents.rename(documentId:name:)`** — `PATCH /documents/{id}`.
- **`client.documents.search(search:status:accountId:)`** — `GET /accounts/{id}/documents/search`.
- **`client.assignments.list(params:accountId:)`** — `GET /assignments` (account context
  supplied via the undocumented-but-required `accountId` query parameter, verified live).
- **`client.auth.currentUser()`** — `GET /users/self` (returns `SelfResponse`).
- **`client.auth.stats(params:)`** — `GET /users/self/stats` (production-only; 404 on sandbox).
- **`client.auth.linkSocialLogin(_:)`** — `POST /auth/link-social-login`.
- **`client.workspaces.theme(accountId:)`** — `GET /accounts/{id}/theme` (`AccountTheme`,
  the canonical source of branding colours).
- **`client.workspaces.stats(params:accountId:)`** — `GET /accounts/{id}/stats`
  (`DocumentStatsRow` series; production-only, 404 on sandbox).
- **`client.workspaces.downloadLogo/uploadLogo/deleteLogo`** — account logo endpoints.
- **`client.signers.searchSignerDocuments(...)`** — `GET /signers/{id}/documents/search`.
- **`AssinafyClient.socialLoginAuthorizationURL(authClient:)`** — builds the
  `GET /auth/authenticate` OAuth-start URL.
- Ordered-signing support: `SignerReference.descriptor(..., step:)` now encodes the
  assignment signer `step`, and `Signer.step` is decoded from responses.
- `client.signers.uploadSignature(..., reuse:)` forwards the `reuse` query flag.
- `Objective-C` completion-handler wrappers for all of the above.

### Fixed
- **`WebhookDispatch.createdAt`/`updatedAt` are now `String?`** (ISO-8601). They were
  typed `Int`, which crashed decoding on real delivery records.
- **Account create/update now send `notification_sender_type`** (per the spec) instead
  of `primary_color`/`secondary_color`, which the API silently ignored (verified live).
  Branding colours are exposed read-only via `workspaces.theme(...)`.
- **`workspaces.delete(workspaceId:force:)`** now sends the documented `{ "force": … }` body.
- **`send-token` request now uses the documented `email` field** (was `recipient`/`channel`);
  the WhatsApp channel still sends `channel`.
- **`ConfirmSignerDataPayload`** now also carries the documented `full_name`/`government_id`.

### Removed
- **Signer `cpf`** from `CreateSignerPayload`/`UpdateSignerPayload`/`Signer`/`SignerInput`.
  Live testing confirmed the API silently drops `cpf`/`government_id` on signer create/update.
- **`WebhookResource.delete()`** is deprecated and now forwards to `inactivate()`
  (`PUT /accounts/{id}/webhooks/inactivate`); the API has no DELETE for subscriptions
  (the old path returned `404`).

### Documentation
- `docs/API_REFERENCE.md` refreshed to cover all endpoints with request/response payloads.

## [1.2.1] - 2026-06-05

### Fixed
- **Assignment decoding no longer crashes on `"method": null`.** The documented
  collect-assignment create response returns a null method; the SDK now decodes
  defensively and defaults to `virtual`.
- **Assignment expiry is no longer dropped.** Decoding now accepts both the live
  API's `expires_at` key and the docs' `expiration` key for `Assignment.expiresAt`.
- **Live test harness can target the sandbox.** `AssinafyLiveTests` now honours an
  `ASSINAFY_BASE_URL` environment variable; previously it hard-coded the production
  host, so sandbox API keys failed with `401 Credenciais inválidas`.
- **Document live test waits for a deletable state** (`waitUntilReady`) before
  deleting, fixing a `400` when the document was still `metadata_processing`.

### Changed
- Extracted the duplicated PDF validation and multipart-body construction from
  `DocumentResource`/`TemplateResource` into shared `PDFValidation` and
  `MultipartFormData` helpers (byte-identical output; DRY).

### Added
- `docs/API_REFERENCE.md` — full request/response payload reference for every
  public SDK method, verified against the live sandbox API.
- `testLiveAssignmentFlow` — end-to-end live coverage of upload → wait → create
  signers → estimate cost → create assignment.
- Regression tests for null-method and `expiration`/`expires_at` assignment decoding.

## [1.2.0] - 2026-05-27

### Added — full API coverage
The SDK now wraps every endpoint documented at
<https://api.assinafy.com.br/v1/docs>. New surfaces:

- **`client.tags`** (new resource) — workspace tag CRUD plus document tag
  list, replace, append, and detach endpoints.
- **`client.fields`** (new resource) — `create`, `list`, `get`, `update`,
  `delete`, `validate`, `validateMultiple`, `listFieldTypes`. Supports both
  authenticated-user and signer-access-code flows on the validate endpoints.
- **`client.documents`** — `listStatuses`, `getPublicInfo` (public, no
  auth), `sendPublicSignToken` (public, no auth), document-specific filters,
  document tag decoding, and template instantiation with editor fields, tags,
  signer notification methods, and signer step ordering.
- **`client.assignments`** — `sign(documentId:assignmentId:signerAccessCode:fields:)`,
  `decline(documentId:assignmentId:signerAccessCode:reason:)`,
  `listWhatsappNotifications(documentId:assignmentId:)`. Assignment responses
  now decode items, signing URLs, summary signers, notification history, and
  documented cost estimate fields.
- **`client.signers`** — `getCurrentDocument`, `listSignerDocuments`,
  `signMultipleDocuments`, `declineMultipleDocuments`,
  `downloadSignerDocumentArtifact`, `getSigningDocument` — the signer-facing
  document endpoints driven by a signer access code. Signers may now be created
  with email or WhatsApp contact details, matching the documented nullable
  email response shape.
- **`client.templates`** — `create(name:pdfData:)`, `update(templateId:payload:)`,
  `delete(templateId:)`. Template responses now expose `documentName`,
  `message`, roles, pages, field placements, tags, default document tags, and
  template-specific list filters.

New model types include `FieldDefinition`, `FieldTypeInfo`,
`FieldValidationResult`, `FieldValidateMultipleItem`, `CreateFieldPayload`,
`UpdateFieldPayload`, `FieldListParams`, `DocumentStatusInfo`,
`PublicDocumentInfo`, `SendTokenPayload`, `SendTokenResponse`,
`SignAssignmentField`, `DeclineAssignmentPayload`, `WhatsappNotification`,
`SignMultipleDocumentsPayload`, `DeclineMultipleDocumentsPayload`,
`SignerDocumentListParams`, `UpdateTemplatePayload`, `Tag`, `TagListParams`,
`CreateTagPayload`, `UpdateTagPayload`, `DocumentListParams`,
`TemplateListParams`, `TemplatePage`, `TemplateFieldPlacement`,
`TemplateEditorField`, `AssignmentItem`, and `AssignmentSigningURL`.

### Tests
- Added unit coverage for tag endpoints, documented filters, nullable signer
  email, richer document/template/assignment decoding, and live-test gating.
- `swift test`: 157 tests, 0 failures, with four credential-gated live tests
  skipped by default.
- Verified against the live `https://api.assinafy.com.br/v1` API using
  environment-only credentials: read-only catalog/list endpoints, tag CRUD,
  signer CRUD, and opt-in document upload/get/download/delete all passed.

## [1.1.1] - 2026-05-11

### Fixed
- `Assignment.copyReceivers` now decodes the array of signer objects that the
  API actually returns (previously typed as `[String]?`, which would throw at
  decode time whenever the field was populated). The companion
  `CreateAssignmentPayload.copyReceivers` continues to accept signer-ID
  strings, matching the documented request shape.
- `DocumentResource.waitUntilReady` no longer issues a second `GET /documents/{id}`
  after detecting the ready status; the polled response is returned directly
  and the helper also unblocks on `pending_signature`, `certificating`, and
  `certificated` statuses for documents that move past `metadata_ready` while
  polling. The thrown error now includes the document ID and last observed
  status in its context.

### Added
- `DocumentArtifacts.thumbnail` exposes the document thumbnail URL when the
  server returns one (it appears after metadata processing completes).

### Changed
- The internal `URLSession` is now configured as ephemeral with cookies and
  caching disabled, so multiple `AssinafyClient` instances cannot share
  cookies/credentials and cached responses can never serve stale data.

### Tests
- New unit tests cover `copy_receivers` decoding (both populated and missing),
  `DocumentArtifacts.thumbnail` decoding, and the `waitUntilReady` happy
  paths/failure cases.
- Verified end-to-end against the live `https://api.assinafy.com.br/v1` API
  for all 21 documented endpoint groups that the SDK exposes.

## [1.1.0] - 2026-05-08

### Added
- Authentication endpoints for login, social login, password reset, and API key management
- Typed `CostEstimate` model returned by `assignments.estimateCost`, `assignments.estimateResendCost`, and `documents.estimateCostFromTemplate`
- `AssinafyClient.sdkVersion` constant exposed in the `User-Agent` header

### Changed
- Audit pass: stripped non-iOS Swift availability annotations and aligned every endpoint with https://api.assinafy.com.br/v1/docs
- Consolidated Objective-C completion-handler bridges through shared `BaseResource` helpers
- `User-Agent` header now reports the actual SDK version

### Removed
- Undocumented `metadata` multipart field from `documents.upload`
- Undocumented `sandboxBaseURL` constant; clients can still pass any base URL via `AssinafyClientConfiguration`

## [1.0.0] - 2024-01-01

### Added
- Initial release
- Document upload and management
- Signer CRUD operations
- Signing assignments (virtual and collect methods)
- Webhook subscriptions
- Document templates
- Workspace management
- Full Objective-C bridging support
- Swift async/await and completion handler APIs
