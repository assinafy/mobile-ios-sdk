# Changelog

## [1.4.0] - 2026-08-27

### Security
- The workspace credential (`Authorization` / `X-Api-Key`) is now sent only to operations
  that accept it. Every operation the v1 API declares as public or as authenticated by the
  `signer-access-code` query parameter is issued without it, so an API-key or bearer-token
  client cannot transmit its credential to a route that has no use for one.

### Added
- `APIRequest.Credential`, the `APIRequest(method:path:queryItems:body:contentType:credential:)`
  initializer, and `APIRequest.withoutWorkspaceCredential()` for custom transports and
  callers that build requests directly.

### Changed
- The `Live Sandbox` workflow runs on every push to `main` in addition to release tags,
  scheduled runs, and manual dispatch. It always runs exactly one suite and fails when no
  live test actually ran, so a run that never reached the API can no longer report success.

## [1.3.1] - 2026-08-27

### Security
- Configuration validation rejects conflicting or malformed credentials, unsafe base URLs,
  invalid identifiers, and invalid timeouts before a request is sent.
- Redirect handling prevents credentials from being forwarded to another origin and rejects
  unsafe redirects while preserving credential-free HTTPS downloads.

### Fixed
- Request encoding and response decoding now handle the documented nullable and alternate
  payload shapes across assignments, authentication, documents, fields, signers, tags,
  templates, webhooks, and workspaces.
- Task cancellation is preserved as `CancellationError`, and bridged network errors retain
  their underlying `URLError` codes.
- Tag pagination and document-tag resolution handle multi-page results consistently.

### Added
- Objective-C-compatible configuration initialization and explicit configuration validation.
- Typed workspace-deletion restrictions on `APIError`.
- Release API compatibility checks, warning-free documentation and iOS test builds, and
  credential-gated sandbox workflows for scheduled and tagged runs.
- Expanded unit, contract, and opt-in sandbox coverage plus complete public request and
  response payload documentation.

## [1.3.0] - 2026-08-21

### Added — new endpoint coverage
- **`client.documents.rename(documentId:name:)`** — `PATCH /documents/{id}`.
- **`client.documents.search(search:status:accountId:)`** — `GET /accounts/{id}/documents/search`.
- **`client.assignments.list(params:accountId:)`** — `GET /assignments`, with an
  optional account-context compatibility query.
- **`client.auth.currentUser()`** — `GET /users/self` (returns `SelfResponse`).
- **`client.auth.stats(params:)`** — `GET /users/self/stats`.
- **`client.auth.linkSocialLogin(_:)`** — `POST /auth/link-social-login`.
- **`client.workspaces.theme(accountId:)`** — `GET /accounts/{id}/theme` (`AccountTheme`,
  the canonical source of branding colours).
- **`client.workspaces.stats(params:accountId:)`** — `GET /accounts/{id}/stats`
  (`DocumentStatsRow` series).
- **`client.workspaces.downloadLogo/uploadLogo/deleteLogo`** — account logo endpoints.
- **`client.signers.searchSignerDocuments(...)`** — `GET /signers/{id}/documents/search`.
- **`AssinafyClient.socialLoginAuthorizationURL(authClient:)`** — builds the
  `GET /auth/authenticate` OAuth-start URL.
- Ordered-signing support: `SignerReference.descriptor(..., step:)` now encodes the
  assignment signer `step`, and `Signer.step` is decoded from responses.
- `client.signers.uploadSignature(..., reuse:)` forwards the `reuse` query flag.
- `Objective-C` completion-handler wrappers for all of the above.

### Fixed
- **`WebhookDispatch.createdAt`/`updatedAt` decode ISO-8601 values as `String?`.**
- **Account create/update send `notification_sender_type`.**
  Branding colours are exposed read-only via `workspaces.theme(...)`.
- **`workspaces.delete(workspaceId:force:)`** now sends the documented `{ "force": … }` body.
- **`send-token` requests use the documented `email` field**; the WhatsApp
  channel also sends `channel`.
- **`ConfirmSignerDataPayload`** now also carries the documented `full_name`/`government_id`.

### Removed
- **Signer `cpf`** from `CreateSignerPayload`/`UpdateSignerPayload`/`Signer`/`SignerInput`.
- **`WebhookResource.delete()`** is deprecated and now forwards to `inactivate()`
  (`PUT /accounts/{id}/webhooks/inactivate`); the API has no DELETE for subscriptions.

### Documentation
- `docs/API_REFERENCE.md` refreshed with request/response payloads for supported
  SDK operations.

## [1.2.1] - 2026-06-05

### Fixed
- **Assignment decoding accepts `"method": null`** and defaults it to `virtual`.
- **Assignment expiry decoding accepts `expires_at` and `expiration`** for
  `Assignment.expiresAt`.
- **The credential-gated test harness accepts `ASSINAFY_BASE_URL`** for an
  explicit sandbox target.
- **Document mutation tests call `waitUntilReady`** before deleting.

### Changed
- Extracted the duplicated PDF validation and multipart-body construction from
  `DocumentResource`/`TemplateResource` into shared `PDFValidation` and
  `MultipartFormData` helpers (byte-identical output; DRY).

### Added
- `docs/API_REFERENCE.md` — request/response payload reference for public SDK methods.
- Regression tests for null-method and `expiration`/`expires_at` assignment decoding.

## [1.2.0] - 2026-05-27

### Added — resources and endpoints

New surfaces:

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
- Credential-gated integration tests remain skipped by default.

## [1.1.1] - 2026-05-11

### Fixed
- `Assignment.copyReceivers` now decodes the array of signer objects that the
  API returns. The companion
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

## [1.1.0] - 2026-05-08

### Added
- Authentication endpoints for login, social login, password reset, and API key management
- Typed `CostEstimate` model returned by `assignments.estimateCost`, `assignments.estimateResendCost`, and `documents.estimateCostFromTemplate`
- `AssinafyClient.sdkVersion` constant exposed in the `User-Agent` header

### Changed
- Removed non-iOS Swift availability annotations and aligned supported endpoints
  with <https://api.assinafy.com.br/v1/docs>.
- Consolidated Objective-C completion-handler bridges through shared `BaseResource` helpers
- `User-Agent` header now reports the actual SDK version

### Removed
- The unused `metadata` multipart field from `documents.upload`
- The `sandboxBaseURL` constant; clients can still pass any base URL via `AssinafyClientConfiguration`

## [1.0.0] - 2024-01-01

### Added
- Initial release
- Document upload and management
- Signer CRUD operations
- Signing assignments (virtual and collect methods)
- Webhook subscriptions
- Document templates
- Workspace management
- Objective-C bridging support
- Swift async/await and completion handler APIs
