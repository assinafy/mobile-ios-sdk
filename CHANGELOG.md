# Changelog

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
