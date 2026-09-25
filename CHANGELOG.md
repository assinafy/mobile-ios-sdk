# Changelog

## [Unreleased]

## [1.8.0] - 2026-09-25

### Added
- `DocumentVerification.agreementCode` exposes the `agreement_code` printed on the document
  certificate, with an `init(signatureHash:id:agreementCode:status:…)` initializer alongside the
  existing one.
- `APIError.insufficientScope` returns the scope named by a `403`
  `WWW-Authenticate: Bearer error="insufficient_scope", scope="…"` challenge, so an app can ask the
  user to connect again with that scope added.
- An `APIError` bridged to `NSError` carries `userInfo["insufficientScope"]` and the raw challenge
  as `userInfo["wwwAuthenticate"]`, so Objective-C callers can read the missing scope.

### Changed
- `POST /oauth/token` and `POST /oauth/revoke` send `application/x-www-form-urlencoded` bodies, the
  encoding RFC 6749 and RFC 7009 define.
- `refreshAccessToken(_:)` throws `AssinafySDKError` when a successful response carries no new
  refresh token, a blank one, or the one sent: the token sent is retired either way.

### Security
- `OAuthCallback.validate(against:issuer:)` checks `state` and `iss` before anything else, on error
  redirects too, so a forged `error=` redirect is rejected rather than reported as the user's
  decision. Without an `issuer:` argument it checks `iss` against `OAuthResource.defaultIssuer`,
  and a callback without `iss` is rejected.
- `POST /oauth/token` and `POST /oauth/revoke` follow no redirect: a `3xx` throws `APIError` rather
  than sending the code or token again.

### Documentation
- The OAuth refresh example saves the renewed tokens first, builds a new client from the new access
  token, and revokes the refresh token saved last. After a refresh fails without an OAuth error, a
  saved refresh token that is still the one sent is never sent again: the user connects again.
  Only failures before the request left — DNS, a refused connection, the TLS handshake — are safe
  to retry.

## [1.7.1] - 2026-09-25

### Security
- The SDK's own HTTPS client now requires TLS 1.2 or newer; TLS 1.0 and 1.1 are refused. Caller-supplied clients are unchanged.

## [1.7.0] - 2026-09-23

### Added
- `OAuthScope.webhooksWrite` can be passed to the existing `scopeStrings` initializer to request permission to configure and deactivate a workspace webhook subscription.

## [1.6.0] - 2026-09-21

### Fixed
- `buildAssignmentEstimateBody` now requires at least one signer in both methods and always sends
  the `signers` key. The published contract marks `signers` as required only for `virtual`, but the
  API prices per signer in both modes and answers a signer-less estimate with
  `400 "Pelo menos um signatários precisa ser informado."` The builder nil'd the key when the list
  was empty, so a `collect` estimate could never be priced.

## [1.5.0] - 2026-09-20

### Added
- OAuth 2.1 support through `client.oauth`: the authorization code flow with mandatory PKCE
  (S256), token exchange and refresh, token revocation, OpenID Connect userinfo, and RFC 9728
  / RFC 8414 discovery of the protected resource and its authorization server.
- `OAuthPKCE` generates a code verifier and S256 challenge from 256 bits of secure randomness,
  and `OAuthAuthorizationRequest` builds the authorization URL without ever placing the
  verifier in it.
- `OAuthCallback.validate(against:issuer:)` verifies a redirect before its code is exchanged,
  comparing `state` in constant time and checking the RFC 9207 `iss` parameter.
- `APIError.oauthError` exposes the flat `{error, error_description}` body that the OAuth
  endpoints return in place of the API envelope.
- `SignerVerificationMethod` and `SignerNotificationMethod` give the signer's verification and
  notification channels typed values — `Email`, `Whatsapp`, and the ICP-Brasil A1/A3
  `DigitalCertificate`. `SignerReference.signer(id:verification:notifications:step:)` and
  `TemplateSigner(roleId:id:verification:notifications:step:)` accept them, and
  `Signer.verification` and `Signer.notifications` read them back.

### Security
- The transport withholds `Authorization` and `X-Api-Key` from any request whose URL does not
  share the base URL's origin, so a credential cannot reach the authorization server or any
  other host through a mistaken absolute path.
- An absolute request URL must be HTTPS and free of embedded credentials; anything else is
  rejected as a `ValidationError` rather than resolved as a relative path.

### Changed
- `README.md` is a complete guide to the SDK in Portuguese, covering the full document
  lifecycle, both sides of the signing flow, and OAuth.

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
