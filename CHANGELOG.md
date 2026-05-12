# Changelog

## [1.2.0] - 2026-05-11

### Added — full API coverage
The SDK now wraps every endpoint documented at
<https://api.assinafy.com.br/v1/docs>. New surfaces:

- **`client.fields`** (new resource) — `create`, `list`, `get`, `update`,
  `delete`, `validate`, `validateMultiple`, `listFieldTypes`. Supports both
  authenticated-user and signer-access-code flows on the validate endpoints.
- **`client.documents`** — `listStatuses`, `getPublicInfo` (public, no
  auth), `sendPublicSignToken` (public, no auth).
- **`client.assignments`** — `sign(documentId:assignmentId:signerAccessCode:fields:)`,
  `decline(documentId:assignmentId:signerAccessCode:reason:)`,
  `listWhatsappNotifications(documentId:assignmentId:)`.
- **`client.signers`** — `getCurrentDocument`, `listSignerDocuments`,
  `signMultipleDocuments`, `declineMultipleDocuments`,
  `downloadSignerDocumentArtifact` — the signer-facing document endpoints
  driven by a signer access code.
- **`client.templates`** — `create(name:pdfData:)`, `update(templateId:payload:)`,
  `delete(templateId:)`. `TemplateDetails` now exposes `documentName` and
  `message`.

New model types include `FieldDefinition`, `FieldTypeInfo`,
`FieldValidationResult`, `FieldValidateMultipleItem`, `CreateFieldPayload`,
`UpdateFieldPayload`, `FieldListParams`, `DocumentStatusInfo`,
`PublicDocumentInfo`, `SendTokenPayload`, `SendTokenResponse`,
`SignAssignmentField`, `DeclineAssignmentPayload`, `WhatsappNotification`,
`SignMultipleDocumentsPayload`, `DeclineMultipleDocumentsPayload`,
`SignerDocumentListParams`, `UpdateTemplatePayload`.

### Tests
- Added 36 unit tests covering every new endpoint and its decoding paths,
  including new `FieldResourceTests` and `TemplateResourceTests` suites
  (total: 135 unit tests passing).
- Verified end-to-end against the live `https://api.assinafy.com.br/v1`
  API for 32 endpoints exercised in sequence (documents, signers,
  assignments, workspaces, templates, fields, webhooks, public document
  info). Signer-access-code-only endpoints (sign, decline, sign-multiple,
  decline-multiple, signer document views, public send-token) are covered
  by unit tests; they require a real signer access code obtained by the
  signer through email/WhatsApp delivery, which is not available to an
  automated test runner.

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
