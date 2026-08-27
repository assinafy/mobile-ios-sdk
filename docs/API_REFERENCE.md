# Assinafy iOS SDK API reference

This reference documents every public Swift `async` SDK operation, its exact
HTTP request, decoded result, compatibility behavior, and error surface. The
authoritative API sources are the
[Assinafy API documentation](https://api.assinafy.com.br/v1/docs) and its
[OpenAPI document](https://api.assinafy.com.br/v1/docs/openapi.json).

Examples in this file are synthetic. They use reserved `example.test` addresses
and illustrative opaque IDs; none were copied from a customer, production, or
sandbox account.

## Conventions

Paths below are relative to the SDK's default production base URL,
`https://api.assinafy.com.br/v1`.

- **Account auth** means either `Authorization: Bearer {token}` or
  `X-Api-Key: {api-key}`. Account-scoped methods use their `accountId` argument,
  then the client's `defaultAccountId`.
- **Signer auth** means the exact query parameter
  `signer-access-code={signer-access-code}`. It is not sent in a JSON body or a
  header.
- **Public** means the v1 OpenAPI operation declares no authentication.
- The **Auth** column is enforced, not merely descriptive. The transport
  attaches `Authorization` and `X-Api-Key` only to **Account** operations. A
  client configured with a bearer token or API key never transmits it to a
  **Signer** or **Public** operation, so a workspace credential cannot reach a
  route that has no use for it.
- JSON responses normally use
  `{ "status": integer, "message": string, "data": value }`. The SDK unwraps
  `data`. A **bare envelope** has no documented result model; `Void` methods
  validate the HTTP/envelope status and discard its body.
- Binary operations return raw `Data` rather than an envelope.
- List operations return `PaginatedResult<T>`. `data` comes from the envelope;
  `meta` is built from `X-Pagination-Current-Page`,
  `X-Pagination-Per-Page`, `X-Pagination-Total-Count`, and
  `X-Pagination-Page-Count` when those headers are present.
- Query names, JSON keys, enum values, and case are significant. Optional means
  the key is omitted unless the method description explicitly says it sends
  JSON `null`.
- The SDK labels a small number of source-compatible overloads and host-specific
  request fields as **compatibility** behavior. Prefer the canonical methods for
  new code. Compatibility endpoints that are not in the v1 OpenAPI document may
  not be available on every configured host.

## Client configuration

`AssinafyClientConfiguration` is the complete configuration surface:

```swift
let configuration = AssinafyClientConfiguration(
    apiKey: nil,
    token: bearerToken,
    baseURL: AssinafyClientConfiguration.productionBaseURL,
    defaultAccountId: accountId,
    timeout: 30,
    logger: NoopLogger()
)
try configuration.validate()
let client = AssinafyClient(configuration: configuration)
```

| Public symbol | Behavior |
| --- | --- |
| `AssinafyClientConfiguration.productionBaseURL` | `https://api.assinafy.com.br/v1` |
| `init(apiKey:token:baseURL:defaultAccountId:timeout:logger:)` | Full Swift initializer. Both credentials may be `nil` for public operations, but they may not both be non-`nil`. |
| `init(apiKey:token:baseURL:defaultAccountId:timeout:)` | Objective-C-compatible initializer using `NoopLogger`. |
| `validate()` | Validates configuration immediately. The client also retains any validation failure and throws it before every request. |
| `AssinafyClient(configuration:)` | Designated client initializer. Exposes `auth`, `workspaces`, `signers`, `documents`, `assignments`, `templates`, `tags`, `fields`, and `webhooks`. |
| `AssinafyClient(apiKey:defaultAccountId:baseURL:)` | API-key convenience initializer, including a custom base URL. API keys are intended for trusted backend or controlled tooling, not distributed apps. |
| `AssinafyClient(token:defaultAccountId:)` | Bearer-token convenience initializer using the production base URL. Use the full configuration initializer when a bearer token must target another host. |
| `AssinafyClient.sdkVersion` | SDK version included as `assinafy-ios-sdk/{version}` in `User-Agent`. |
| `socialLoginAuthorizationURL(authClient:)` | Builds `{baseURL}/auth/authenticate?authclient={value}`. Returns `nil` for invalid configuration or a blank provider value; it performs no network request. |

Validation rejects blank credentials; credentials containing whitespace or
control characters; simultaneous API-key and bearer-token configuration; a
non-finite or non-positive timeout; unsafe account IDs (`.`, `..`, control
characters, `/`, `\`, `?`, or `#`); and a base URL that is not absolute HTTPS,
has no host, or contains user information, query, or fragment. Trailing slashes
are removed from accepted base URLs. Resource methods resolve an explicit
`accountId` first and then `defaultAccountId`; absence of both produces a local
`ValidationError` before network I/O.

The built-in transport always sends `Accept: application/json` and the SDK
`User-Agent`. It sends exactly one credential header: `Authorization: Bearer
{token}` or `X-Api-Key: {api-key}`.

## Authentication and current user

All methods in this section are available through `client.auth`.

| Async SDK method | Auth | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `login(_:)` | Public | `POST /login`; JSON `email` and `password`, both required | `data: AuthSession` -> `LoginResponse` |
| `socialLogin(_:)` | Public | `POST /authentication/social-login`; JSON `provider` (`google`), `token`, and `has_accepted_terms`, all required | `data: AuthSession` -> `LoginResponse` |
| `linkSocialLogin(_:)` | Account | `POST /auth/link-social-login`; JSON `provider` (`google`) and `token`, both required | Bare envelope; returns `Void` |
| `currentUser()` | Account | `GET /users/self` | `data` is a direct `AuthUser`, normalized to `SelfResponse(user: data, accounts: [])`. The decoder also accepts the former `{user, accounts}` data wrapper. |
| `currentUserProfile()` | Account | `GET /users/self` | Returns `User`; accepts both documented direct `data: User` and the sandbox compatibility `{user, accounts}` wrapper. |
| `getNotificationPreferences()` | Account | `GET /users/self/notification-preferences` | `data: NotificationPreferences` |
| `updateNotificationPreferences(_:)` | Account | `PUT /users/self/notification-preferences`; partial `NotificationPreferences` JSON; at least one key is required by the SDK | The complete updated `NotificationPreferences` |
| `stats(params:)` | Account | `GET /users/self/stats`; optional `granularity=monthly|daily`, `month=YYYY-MM` | `[DocumentStatsRow]` |
| `changePassword(_:)` | Account | `PUT /authentication/change-password`; required JSON `email`, `password`, `new_password` | Documented `data.email`; SDK returns `Void` |
| `changePasswordAndReturnResponse(_:)` | Account | Same request as `changePassword(_:)` | Canonical `EmailResponse` with `email` |
| `requestPasswordReset(_:)` | Public | `PUT /authentication/request-password-reset`; required JSON `email` | Documented `data.email`; SDK returns `Void` |
| `requestPasswordResetAndReturnResponse(_:)` | Public | Same request as `requestPasswordReset(_:)` | Canonical `EmailResponse` with `email` |
| `resetPassword(_:)` | Public | `PUT /authentication/reset-password`; required JSON `email`, `new_password`; optional `token` | Documented `data.email`; SDK returns `Void` |
| `resetPasswordAndReturnResponse(_:)` | Public | Same request as `resetPassword(_:)` | Canonical `EmailResponse` with `email` |
| `getAPIKey()` | Account | `GET /users/api-keys` | `data.api_key: string|null`; SDK returns `String?` |
| `createAPIKey(_:)` | Account | `POST /users/api-keys`; required JSON `password` | `data.api_key: string|null`; SDK requires a nonempty value and returns `String` |
| `deleteAPIKey()` | Account | `DELETE /users/api-keys` | Documented `data: []`; returns `Void` |

`NotificationPreferences` has exactly these nine Boolean wire keys. The update
payload uses the same keys and may send any nonempty subset:

```json
{
  "DocumentCompleted": true,
  "SignerDeclined": true,
  "DocumentCancelled": true,
  "DocumentAboutToExpire": true,
  "DocumentExpired": true,
  "DocumentExpirationReset": true,
  "DocumentProcessingFailed": true,
  "TemplateProcessingFailed": true,
  "SignerWhatsappFailed": true
}
```

## Workspaces (accounts)

All methods are available through `client.workspaces` and require account auth.

| Async SDK method | Exact request | Wire response and SDK result |
| --- | --- | --- |
| `create(_:)` | `POST /accounts`; required JSON `name`; optional `notification_sender_type=User|Account`. The sandbox host rejects that optional key, so the SDK omits it there. | `data: Account` -> `WorkspaceResponse` |
| `list(params:)` | `GET /accounts`; no query is emitted | `[Account]` -> `PaginatedResult<WorkspaceListItem>` |
| `get(workspaceId:)` | `GET /accounts/{workspaceId}` | `Account` -> `WorkspaceResponse` |
| `update(workspaceId:payload:)` | `PUT /accounts/{workspaceId}`; partial JSON `name`, `notification_sender_type=User|Account` | Updated `Account` |
| `delete(workspaceId:force:)` | `DELETE /accounts/{workspaceId}`; JSON `force: boolean` | Documented `data: []`; returns `Void` |
| `theme(accountId:)` | `GET /accounts/{accountId}/theme` | `AccountTheme` |
| `stats(params:accountId:)` | `GET /accounts/{accountId}/stats`; optional `granularity=monthly|daily`, `month=YYYY-MM` | `[DocumentStatsRow]` |
| `downloadLogo(accountId:)` | `GET /accounts/{accountId}/logo` | Raw image `Data` |
| `uploadLogo(_:filename:contentType:accountId:)` | `POST /accounts/{accountId}/logo`; multipart field `file` is required and uses the supplied filename/content type | Bare envelope; returns `Void` |
| `deleteLogo(accountId:)` | `DELETE /accounts/{accountId}/logo` | Bare envelope; returns `Void` |

`GET /accounts` declares no query parameters. The `ListParams` argument remains
source-compatible, but the SDK intentionally emits no account-list search,
pagination, sort, or `extra` query values.

Workspace deletion can return a `400` envelope with a top-level `restrictions`
array. Catch `APIError` and read `workspaceDeletionRestrictions`; each
`WorkspaceDeletionRestriction` contains `code`, `message`, and `accountIds`.
Known codes are `ActivePaidSubscription` and `PendingDocuments`. Passing
`force: true` asks the service to resolve supported blockers before deletion.

## Signers

Workspace management methods require account auth. Signer-facing methods use the
signer code exactly where shown.

| Async SDK method | Auth | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `create(_:accountId:)` | Account | `POST /accounts/{accountId}/signers`; required `full_name`; optional `email`, `whatsapp_phone_number` | `Signer`. If `email` is present, the SDK first searches and reuses an exact case-insensitive match. Full-name-only creation is supported. |
| `get(signerId:accountId:)` | Account | `GET /accounts/{accountId}/signers/{signerId}` | `Signer` |
| `list(params:accountId:)` | Account | `GET /accounts/{accountId}/signers`; v1 values are optional `search`, `page`, `per-page`; generic `ListParams` also forwards nonempty compatibility `sort` and caller-defined `extra` | `PaginatedResult<Signer>` |
| `update(signerId:payload:accountId:)` | Account | `PUT /accounts/{accountId}/signers/{signerId}`; partial `full_name`, `email`, `whatsapp_phone_number`, `government_id` | Updated `Signer` |
| `delete(signerId:accountId:)` | Account | `DELETE /accounts/{accountId}/signers/{signerId}` | Documented `data: []`; returns `Void` |
| `findByEmail(_:accountId:)` | Account | Helper over signer list with `search={email}&per-page=100`; filters returned emails case-insensitively | Matching `Signer?`; a 404 becomes `nil` |
| `getSelf(signerAccessCode:)` | Signer | `GET /signers/self?signer-access-code={code}` | `SignerSelf` -> `SignerSelfInfo` |
| `acceptTerms(signerAccessCode:)` | Signer | `PUT /signers/accept-terms?signer-access-code={code}`; no JSON body | Bare envelope. The source-compatible `AcceptTermsResponse` is synthesized as `fullName: ""`, `email: ""`, `hasAcceptedTerms: true`; a legacy response body is still decoded. |
| `acceptTermsWithoutResponse(signerAccessCode:)` | Signer | Same request as `acceptTerms(signerAccessCode:)` | Canonical bare-envelope handling; returns `Void` |
| `verifyEmail(payload:)` | Signer | `POST /verify?signer-access-code={code}`; JSON contains only `verification-code` | Bare envelope; returns `Void`. `signerAccessCode` is never emitted in the body. |
| `uploadSignature(signerAccessCode:type:imageData:reuse:)` | Signer | `POST /signature?signer-access-code={code}&type=signature|initial[&reuse=true]`; body is PNG bytes (`image/png`) | Bare envelope; returns `Void` |
| `downloadSignature(signerAccessCode:type:)` | Signer | `GET /signature/{signatureType}?signer-access-code={code}` where the path value is `signature` or `initial` | Raw image `Data`; there is no redundant `type` query |
| `getCurrentDocument(signerId:signerAccessCode:)` | Signer | `GET /signers/{signerId}/document?signer-access-code={code}` | `Document` -> `DocumentDetails`; the API omits pages and limits assignment items to this signer |
| `listSignerDocuments(signerId:signerAccessCode:params:)` | Signer | `GET /signers/{signerId}/documents?signer-access-code={code}`; v1 query values are `page`, `per-page`; the SDK also forwards compatibility `status`, `method`, `search`, `sort` | `PaginatedResult<DocumentDetails>` |
| `searchSignerDocuments(signerId:signerAccessCode:search:status:)` | Signer | `GET /signers/{signerId}/documents/search?signer-access-code={code}`; v1 defines optional `search`; the SDK also forwards compatibility `status` | `PaginatedResult<DocumentDetails>` |
| `signMultipleDocuments(signerAccessCode:documentIds:)` | Signer | `PUT /signers/documents/sign-multiple?signer-access-code={code}`; JSON `document_ids: [string]`, nonempty | Bare envelope; returns `Void` |
| `declineMultipleDocuments(signerAccessCode:documentIds:reason:)` | Signer | `PUT /signers/documents/decline-multiple?signer-access-code={code}`; JSON `document_ids: [string]`, `decline_reason: string` | Bare envelope; returns `Void` |
| `downloadSignerDocumentArtifact(signerId:documentId:artifact:)` | Public | `GET /signers/{signerId}/documents/{documentId}/download/{artifact}` | Raw PDF `Data` |
| `downloadSignerDocumentArtifact(signerId:documentId:artifact:signerAccessCode:)` | Public | Compatibility overload of the preceding operation; the supplied code is intentionally not sent | Raw PDF `Data` |
| `getSigningDocument(signerAccessCode:hasAcceptedTerms:)` | Signer | `GET /sign?signer-access-code={code}`; optional `has_accepted_terms=true|false` | `DocumentDetails` |

Signer document and account document artifact path values are `original`,
`certificated`, `certificate-page`, `pades`, and `bundle`.

The signer-document `status`, `method`, and `sort` filters, plus `status` on the
search endpoint, are compatibility query values. For portable v1 integrations,
use `page` and `perPage` on the list operation and `search` on the search
operation.

## Documents

Unless marked public, document operations require account auth.

| Async SDK method | Auth | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `upload(_:options:)` | Account | `POST /accounts/{accountId}/documents`; multipart required `file` containing a PDF | `Document` -> `DocumentUploadResponse`. The SDK validates PDF magic bytes and the 25 MB limit first. |
| `list(params: ListParams, accountId:)` | Account | `GET /accounts/{accountId}/documents`; optional `page`, `per-page`, `search`, `sort`, plus caller-defined compatibility `extra` queries | `PaginatedResult<DocumentListItem>` |
| `list(params: DocumentListParams, accountId:)` | Account | Same path; optional `status`, `method=virtual|collect`, `search`, `tags` (comma-separated tag IDs), `sort`, `page`, `per-page` | `PaginatedResult<DocumentListItem>` |
| `search(search:status:accountId:)` | Account | `GET /accounts/{accountId}/documents/search`; optional `search`, `status` | Lightweight `PaginatedResult<DocumentListItem>`; preserved source-compatible overload |
| `search(search:status:page:perPage:accountId:)` | Account | Same path; optional `search`, `status`; required Swift pagination arguments below `1` are omitted, otherwise emit `page`, `per-page` | Same result |
| `get(documentId:)` | Account | `GET /documents/{documentId}` | `Document` -> `DocumentDetails` |
| `rename(documentId:name:)` | Account | `PATCH /documents/{documentId}`; JSON `{ "name": string }` | Updated `DocumentDetails` |
| `waitUntilReady(documentId:options:)` | Account | Local polling helper over `GET /documents/{documentId}` | Returns `DocumentUploadResponse` at `metadata_ready`, `pending_signature`, `certificating`, or `certificated`; throws `AssinafySDKError` on `failed`, `expired`, `rejected_by_signer`, `rejected_by_user`, or timeout; invalid intervals throw `ValidationError` |
| `downloadArtifact(documentId:artifact:)` | Account | `GET /documents/{documentId}/download/{artifact}` | Raw PDF/ZIP `Data` |
| `downloadThumbnail(documentId:)` | Account | `GET /documents/{documentId}/thumbnail` | Raw image `Data` |
| `downloadPage(documentId:pageId:)` | Account | `GET /documents/{documentId}/pages/{pageId}/download` | Raw image `Data` |
| `activities(documentId:)` | Account | `GET /documents/{documentId}/activities` | `[DocumentActivity]` |
| `delete(documentId:)` | Account | `DELETE /documents/{documentId}` | Documented `data: []`; returns `Void` |
| `createFromTemplate(templateId:signers:options:accountId:)` | Account | `POST /accounts/{accountId}/templates/{templateId}/documents`; body below | `Document` -> `DocumentUploadResponse` |
| `estimateCostFromTemplate(templateId:signers:accountId:)` | Account | `POST /accounts/{accountId}/templates/{templateId}/documents/estimate-cost`; exact estimate body below | `CostEstimate` |
| `verify(signatureHash:)` | Public | `GET /documents/{signatureHash}/verify` | Projects `DocumentVerification.is_valid` to `Bool` |
| `verifyDetails(signatureHash:)` | Public | Same request | Full `DocumentVerification` |
| `isFullySigned(documentId:)` | Account | Local helper over `GET /documents/{documentId}` | `summary.completed_count >= summary.signer_count && signer_count > 0` |
| `getSigningProgress(documentId:)` | Account | Local helper over `GET /documents/{documentId}` | `SigningProgress(signed, total, pending, percentage)` from assignment summary |
| `listStatuses()` | Account | `GET /documents/statuses` | `[DocumentStatusInfo]` (`code`, `deletable`) |
| `getPublicInfo(documentId:)` | Public | `GET /public/documents/{documentId}` | Full `Document` -> `PublicDocumentInfo`, not a four-field summary |
| `sendPublicSignToken(documentId:email:)` | Public | `PUT /public/documents/{documentId}/send-token`; canonical body `{ "email": string }` | Bare envelope; returns `Void` after one request |
| `sendPublicSignToken(documentId:payload:)` | Public | Compatibility form of the same `PUT`; email sends `{ "email": string }`, while WhatsApp also sends `channel: "whatsapp"`; the Assinafy sandbox host receives `email`, `recipient`, and `channel` | After the successful `PUT`, performs `GET /public/documents/{documentId}` and returns SDK-derived `SendTokenResponse(document, channel, recipient)`. If the lookup fails after delivery, throws `AssinafySDKError` with `context["tokenSent"] == true`. |
| `confirmSignerDataAndReturnSigner(documentId:signerAccessCode:payload:)` | Signer | `PUT /documents/{documentId}/signers/confirm-data?signer-access-code={code}`; body may contain `full_name`, `email`, `government_id`; compatibility keys are described below | Canonical `data: Signer` result |
| `confirmSignerData(documentId:signerAccessCode:payload:)` | Signer | Same request | Source-compatible overload that validates success and discards `data`; returns `Void` |

For document creation from a template, every signer requires `role_id` and `id`.
Optional signer keys are `verification_method=Email|Whatsapp|DigitalCertificate`,
`notification_methods: [Email|Whatsapp]`, and positive `step`. Optional top-level
keys are `editor_fields: [{field_id, value}]`, `name`, `message`, `expires_at`,
and `tags`. Here, and only here, `tags` are tag **names** that the API may create;
the document-tag attachment endpoints use tag IDs.

Template cost estimation intentionally sends a narrower body:

```json
{
  "signers": [
    {
      "role_id": "role_example_001",
      "verification_method": "Email",
      "notification_methods": ["Email"]
    }
  ]
}
```

Only `role_id` is required. Signer IDs, signing steps, editor values, document
metadata, expiry, and tags are not part of the estimate request.

For new email-token integrations, use the one-request `email:` overload. The
payload overload remains available for its synthesized result and WhatsApp
channel support. `ConfirmSignerDataPayload` omits every `nil` optional field and
emits `has_accepted_terms` only when `true`; `whatsapp_phone_number` and
`has_accepted_terms` are compatibility fields accepted by signing flows.

## Assignments

Owner operations require account auth. Signing and decline operations require
signer auth.

| Async SDK method | Auth | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `list(params:accountId:)` | Account | `GET /assignments`; v1 values are optional `page`, `per-page`; generic `ListParams` also forwards compatibility `search`, `sort`, and caller-defined `extra`; `accountId` is emitted when explicit and is filled from the default for the Assinafy sandbox host | `PaginatedResult<Assignment>` |
| `create(documentId:payload:)` | Account | `POST /documents/{documentId}/assignments`; exact body below | `Assignment` |
| `estimateCost(documentId:payload:)` | Account | `POST /documents/{documentId}/assignments/estimate-cost`; exact estimate body below | `CostEstimate` |
| `resetExpiration(documentId:assignmentId:newExpiresAt:)` | Account | `PUT /documents/{documentId}/assignments/{assignmentId}/reset-expiration`; canonical JSON `{ "expires_at": string }`; a blank value is rejected locally | Updated `Assignment` |
| `resetExpiration(documentId:assignmentId:expiresAt:)` | Account | Compatibility overload of the same `PUT`; sends `{ "expires_at": string|null }`, including explicit JSON `null` when omitted | Updated `Assignment` |
| `resendNotification(documentId:assignmentId:signerId:)` | Account | `PUT /documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/resend`; no body | `ResendNotificationResponse` |
| `estimateResendCost(documentId:assignmentId:signerId:)` | Account | `POST` to the preceding signer path plus `/estimate-resend-cost`; no body | `CostEstimate` |
| `sign(documentId:assignmentId:signerAccessCode:fields:)` | Signer | `POST /documents/{documentId}/assignments/{assignmentId}?signer-access-code={code}`; top-level JSON array of `{itemId, fieldId, pageId, value}` | Bare envelope; returns `Void`. Confirm virtual signer data first; an empty array is valid for virtual assignments. |
| `decline(documentId:assignmentId:signerAccessCode:reason:)` | Signer | `PUT /documents/{documentId}/assignments/{assignmentId}/reject?signer-access-code={code}`; JSON `decline_reason` | Bare envelope; returns `Void` |
| `listWhatsappNotifications(documentId:assignmentId:)` | Account | `GET /documents/{documentId}/assignments/{assignmentId}/whatsapp-notifications` | `[WhatsappNotification]` |

The full creation body is:

```json
{
  "method": "collect",
  "signers": [
    {
      "id": "signer_example_001",
      "verification_method": "Email",
      "notification_methods": ["Email"],
      "step": 1
    }
  ],
  "entries": [
    {
      "page_id": "page_example_001",
      "fields": [
        {
          "signer_id": "signer_example_001",
          "field_id": "field_example_001",
          "display_settings": {
            "left": 72,
            "top": 144,
            "width": 320,
            "height": 48,
            "fontFamily": "Example Sans",
            "fontSize": 18,
            "backgroundColor": "#D5EBFF"
          }
        }
      ]
    }
  ],
  "message": "Please review the example document.",
  "expires_at": "2030-12-31T23:59:59Z",
  "copy_receivers": ["signer_example_002"]
}
```

`method` and a nonempty `signers` array are required. Every creation signer must
have `id`; the three descriptor fields are optional. `entries` is required and
nonempty for `collect`. `display_settings` is a JSON object, never a JSON-encoded
string. Its required fields are `left`, `top`, `width`, `height`, and `fontSize`;
`fontFamily` and `backgroundColor` are optional. Coordinates are pixels in the
API's 150-DPI page image. `left` and `top` must be nonnegative; width, height,
and font size must be positive and the rectangle must fit the selected page.

Assignment estimation deliberately removes signer descriptor IDs and steps,
message, expiry, and copy receivers. A virtual estimate requires a nonempty
`signers` array whose entries contain only optional `verification_method` and
`notification_methods`; `{}` means the Email defaults. A collect estimate
requires the same page/field-placement `entries` objects used for creation:

```json
{
  "method": "virtual",
  "signers": [
    { "verification_method": "Email", "notification_methods": ["Email"] }
  ]
}
```

The assignment list operation defines `page` and `per-page`; leave generic
`ListParams.search`, `sort`, and `extra` unset. `accountId` is a compatibility
query value: it is emitted when explicitly supplied and is also added from
`defaultAccountId` when the configured host is `sandbox.assinafy.com.br`.

## Templates

All template methods require account auth.

| Async SDK method | Contract status | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `list(params: ListParams, accountId:)` | v1 operation with compatibility queries | `GET /accounts/{accountId}/templates`; use `search`, `page`, and `per-page`; generic `ListParams` also forwards nonempty `sort` and caller-defined `extra` | `PaginatedResult<TemplateListItem>` |
| `list(params: TemplateListParams, accountId:)` | v1 operation with compatibility queries | Same path; use `search`, `page`, and `per-page`; the SDK also forwards `status`, comma-separated tag IDs as `tags`, and `sort` | Same result |
| `create(name:pdfData:accountId:)` | Compatibility endpoint | `POST /accounts/{accountId}/templates`; multipart required text part `name` and PDF part `file`; the SDK validates a nonblank name, PDF magic bytes, and the 25 MB limit | `TemplateDetails` |
| `get(templateId:accountId:)` | Compatibility endpoint | `GET /accounts/{accountId}/templates/{templateId}` | `TemplateDetails` |
| `update(templateId:payload:accountId:)` | Compatibility endpoint | `PUT /accounts/{accountId}/templates/{templateId}`; partial JSON `name`, `document_name`, `message` | Updated `TemplateDetails` |
| `delete(templateId:accountId:)` | Compatibility endpoint | `DELETE /accounts/{accountId}/templates/{templateId}` | Returns `Void` |

For the documented template list contract, set only `search`, `page`, and
`perPage`. `status`, `tags`, `sort`, and generic `extra` entries are retained for
compatible deployments. Template-definition create, get, update, and delete are
also compatibility endpoints; confirm their availability for the configured
environment before depending on them.

## Tags

All tag methods require account auth.

| Async SDK method | Exact request | Wire response and SDK result |
| --- | --- | --- |
| `list(params:accountId:)` | `GET /accounts/{accountId}/tags`; optional `search` | `PaginatedResult<Tag>` |
| `create(_:accountId:)` | `POST /accounts/{accountId}/tags`; required `name`; optional nullable `color` (six hex digits, with or without input `#`) | `Tag` |
| `update(tagId:payload:accountId:)` | `PUT /accounts/{accountId}/tags/{tagId}`; partial `name`, nullable `color`; `clearsColor` sends `color: null` | Updated `Tag` |
| `delete(tagId:force:accountId:)` | `DELETE /accounts/{accountId}/tags/{tagId}`; optional query `force=true` | Documented `data.deleted: boolean`; SDK returns `Void` |
| `deleteAndReturnStatus(tagId:force:accountId:)` | Same request as `delete(tagId:force:accountId:)` | Canonical `data.deleted: boolean` -> `Bool` |
| `listDocumentTags(documentId:accountId:)` | `GET /accounts/{accountId}/documents/{documentId}/tags` | `[Tag]` |
| `replaceDocumentTags(documentId:tagIds:accountId:)` | `PUT` to the preceding collection; JSON `{ "tags": [tag IDs] }`; an empty array removes all. For a nonempty sandbox request, the SDK first resolves every ID from paginated `GET /accounts/{accountId}/tags?page=N&per-page=100` calls, sends names on the wire, and rejects unresolved IDs. | `[Tag]`; if the sandbox mutation returns empty `data`, the SDK returns a follow-up `GET` of the document's tags |
| `replaceDocumentTags(documentId:tagNames:accountId:)` | Deprecated label-only overload; values are still tag IDs and it forwards to the canonical method | `[Tag]` |
| `appendDocumentTags(documentId:tagIds:accountId:)` | `POST` to the document tag collection; JSON `{ "tags": [tag IDs] }`, nonempty. On sandbox, the SDK first resolves every ID from paginated `GET /accounts/{accountId}/tags?page=N&per-page=100` calls, sends names on the wire, and rejects unresolved IDs. | `[Tag]`; if the sandbox mutation returns empty `data`, the SDK returns a follow-up `GET` of the document's tags |
| `appendDocumentTags(documentId:tagNames:accountId:)` | Deprecated label-only overload; values are still tag IDs and it forwards to the canonical method | `[Tag]` |
| `detachDocumentTag(documentId:tagId:accountId:)` | `DELETE /accounts/{accountId}/documents/{documentId}/tags/{tagId}` | Documented `data.detached: boolean`; SDK returns `Void` |
| `detachDocumentTagAndReturnStatus(documentId:tagId:accountId:)` | Same request as `detachDocumentTag(documentId:tagId:accountId:)` | Canonical `data.detached: boolean` -> `Bool` |

Public tag-attachment parameters are tag IDs. The sandbox-only wire conversion
is internal and does not change that API.

## Fields

The v1 OpenAPI declares account auth for every field operation.

| Async SDK method | Exact request | Wire response and SDK result |
| --- | --- | --- |
| `create(_:accountId:)` | `POST /accounts/{accountId}/fields`; required `name`, `type`; optional `regex`, `is_required` | `Field` -> `FieldDefinition` |
| `list(params:accountId:)` | `GET /accounts/{accountId}/fields`; optional `include_inactive`, `include_standard` | `PaginatedResult<FieldDefinition>` |
| `get(fieldId:accountId:)` | `GET /accounts/{accountId}/fields/{fieldId}` | `FieldDefinition` |
| `update(fieldId:payload:accountId:)` | `PUT /accounts/{accountId}/fields/{fieldId}`; partial `name`, nullable `regex`, `is_active` | Updated `FieldDefinition` |
| `delete(fieldId:accountId:)` | `DELETE /accounts/{accountId}/fields/{fieldId}` | Documented `data: []`; returns `Void` |
| `validate(fieldId:value: String, signerAccessCode:accountId:)` | `POST /accounts/{accountId}/fields/{fieldId}/validate`; JSON `{ "value": string }`; optional compatibility `signer-access-code` query | `FieldValidationResult` |
| `validate(fieldId:value: JSONValue, signerAccessCode:accountId:)` | Same path and query; `value` preserves its string, integer, unsigned integer, number, Boolean, object, array, or null JSON type | `FieldValidationResult` |
| `validateMultiple(items: [FieldValidateMultipleItem], signerAccessCode:accountId:)` | `POST /accounts/{accountId}/fields/validate-multiple`; nonempty top-level array of `{field_id: string, value: string}`; optional compatibility signer query | `[FieldValidationResult]`; each item also carries `field_id` |
| `validateMultiple(items: [FieldJSONValidationItem], signerAccessCode:accountId:)` | Same request with each `value: JSONValue`, preserving the JSON type | `[FieldValidationResult]` |
| `listFieldTypes()` | `GET /field-types` | `[FieldTypeInfo]` |

The SDK retains these compatibility fields:

- Create sends `is_active: false` when requested; `true` is omitted as the
  default.
- Update may send `type` and `is_required`. `clearsRegex` sends `regex: null`.
- `validate` and `validateMultiple` append `signer-access-code={code}` when a
  nonempty code is supplied.

## Webhooks

All webhook methods require account auth.

| Async SDK method | Exact request | Wire response and SDK result |
| --- | --- | --- |
| `register(_:accountId:)` | `PUT /accounts/{accountId}/webhooks/subscriptions`; required `events: [string]`, `is_active: boolean`, `url: URI`, `email: email` | `WebhookSubscription` |
| `get(accountId:)` | `GET /accounts/{accountId}/webhooks/subscriptions` | `WebhookSubscription` |
| `delete(accountId:)` | Deprecated SDK alias for `PUT /accounts/{accountId}/webhooks/inactivate`; the API has no destructive subscription delete | Response discarded; returns `Void` |
| `inactivate(accountId:)` | `PUT /accounts/{accountId}/webhooks/inactivate`; no body | Documented updated `WebhookSubscription` is discarded; returns `Void` |
| `inactivateAndReturn(accountId:)` | Same request | Updated `WebhookSubscription` |
| `listEventTypes()` | `GET /webhooks/event-types` | `[WebhookEventTypeInfo]` |
| `listDispatches(params:accountId:)` | `GET /accounts/{accountId}/webhooks`; optional `event`, `delivered=true|false`, `from`, `to`, `page`, `per-page` | `PaginatedResult<WebhookDispatch>` |
| `retryDispatch(dispatchId:accountId:)` | `POST /accounts/{accountId}/webhooks/{historyId}/retry`; no body | New `WebhookDispatch` |

`from` and `to` are integer Unix timestamps. A dispatch's `http_status` is
nullable when no HTTP response was received; use `httpStatusCode` to preserve
that distinction. The deprecated `httpStatus` compatibility property maps null
to zero.

## Request payload and parameter catalog

The operation tables define where each model is used. This catalog gives the
complete encoded shape for public request models and query containers.

### Authentication and account requests

- `LoginPayload`: required `email: string`, `password: string`.
- `SocialLoginPayload`: required `provider: "google"`, `token: string`,
  `has_accepted_terms: boolean`.
- `LinkSocialLoginPayload`: required `provider: "google"`, `token: string`.
- `ChangePasswordPayload`: required `email`, `password`, `new_password`.
- `RequestPasswordResetPayload`: required `email`.
- `ResetPasswordPayload`: required `email`, `new_password`; optional `token`.
- `CreateAPIKeyPayload`: required `password`.
- `UpdateNotificationPreferencesPayload`: any nonempty subset of the nine
  case-sensitive Boolean notification keys shown above. `nil` values are
  omitted and explicit `false` values are encoded.
- `CreateWorkspacePayload`: required `name`; optional
  `notification_sender_type` (`User` or `Account`). The SDK omits the optional
  key on the sandbox host because that deployment rejects it.
- `UpdateWorkspacePayload`: optional `name` and `notification_sender_type`.
  Omitted keys remain unchanged.
- `delete(workspaceId:force:)`: always sends `{ "force": boolean }` in the
  `DELETE` body.
- `AccountStatsParams`: optional `granularity` (`monthly` or `daily`) and
  `month` (`YYYY-MM`).

### Signer and document requests

- `CreateSignerPayload`: required `full_name`; optional `email` and
  `whatsapp_phone_number`. The SDK rejects a blank name and validates a supplied
  email before searching or creating. With an email, creation first searches
  for and reuses an exact case-insensitive match.
- `UpdateSignerPayload`: partial `full_name`, `email`,
  `whatsapp_phone_number`, and `government_id`. The four-argument initializer
  is used when `government_id` is needed.
- `VerifyEmailPayload`: the initializer accepts `verificationCode` and
  `signerAccessCode`; JSON contains only `{ "verification-code": string }` and
  the access code is emitted only as a query parameter.
- `ConfirmSignerDataPayload`: optional `full_name`, `email`, `government_id`,
  and compatibility `whatsapp_phone_number`; `has_accepted_terms: true` is
  encoded only when requested.
- `SignMultipleDocumentsPayload`: `{ "document_ids": [string] }`.
- `DeclineMultipleDocumentsPayload`: `{ "document_ids": [string],
  "decline_reason": string }`.
- `SendTokenPayload`: `recipient` is encoded under `email`; `channel` is
  omitted for `.email` and encoded as `"whatsapp"` for `.whatsapp`. Prefer the
  canonical `sendPublicSignToken(documentId:email:)` method for email.
- `DocumentUploadOptions`: optional account-ID override; it does not create a
  JSON body. Uploads use multipart field `file` with filename `document.pdf` and
  media type `application/pdf`.
- `DocumentListParams`: optional `status`, `method`, `search`, comma-separated
  tag IDs as `tags`, `sort`; positive `page` and `perPage` become `page` and
  `per-page`.
- `WaitUntilReadyOptions`: local finite positive `maxWaitSeconds` and
  `pollIntervalSeconds`; neither is sent to the API.
- `SignAssignmentField`: top-level signing arrays contain `itemId`, `fieldId`,
  `pageId`, and `value`. The initializer retains an optional `pageId` for source
  compatibility, but `sign(...)` requires all three IDs before sending.

### Assignment and template requests

- `CreateAssignmentPayload`: `method` (`virtual` or `collect`), nonempty
  `signers`, optional `entries`, `message`, `expires_at`, and
  `copy_receivers`. `SignerReference.id` encodes only `id`; descriptor values
  may also encode `verification_method`, `notification_methods`, and positive
  `step`. Creation requires an ID for every signer.
- `AssignmentEntry`: `page_id` and nonempty `fields`. Every field encodes
  `signer_id`, `field_id`, and optional `display_settings`.
- `DisplaySettings`: required finite numeric `left`, `top`, `width`, `height`,
  and `fontSize`; optional `fontFamily`, `backgroundColor`. Left/top must be
  nonnegative and width/height/font size must be positive. The deprecated
  assignment-field initializer accepts a JSON string, decodes it locally to
  this object, and never sends a JSON-encoded string.
- `CreateAssignmentPayload.withSignerIds(...)`: local convenience constructor
  for virtual assignments using signer IDs. It performs no request itself.
- Assignment estimation derives a narrower body from
  `CreateAssignmentPayload`: signer IDs, steps, message, expiry, and copy
  receivers are removed. Virtual estimates require signers; collect estimates
  require entries.
- Canonical expiration reset sends `{ "expires_at": string }`; the compatibility
  `expiresAt:` overload can explicitly send `null`.
- `TemplateSigner`: required `role_id`; document creation also requires `id`.
  Optional values are `verification_method`, `notification_methods`, and
  positive `step`. Template cost estimation removes signer IDs and steps.
- `CreateDocumentFromTemplateOptions`: optional `name`, `message`,
  `expires_at`, nonempty `editor_fields`, and nonempty `tags`. Empty arrays are
  omitted. Each `TemplateEditorField` contains `field_id` and string `value`.
- `UpdateTemplatePayload`: partial `name`, `document_name`, and `message`.
- `TemplateListParams`: optional `status`, `search`, comma-separated tag IDs as
  `tags`, `sort`; positive `page` and `perPage` become `page` and `per-page`.

### Tag, field, webhook, and generic list requests

- `CreateTagPayload`: required `name`, optional nullable `color`. The SDK
  accepts six hexadecimal digits with or without a leading `#`.
- `UpdateTagPayload`: optional `name` and `color`; `clearsColor: true` sends
  `color: null`. At least one change is required.
- `TagListParams`: optional nonempty `search`.
- Document tag replacement and append both accept tag IDs and encode
  `{ "tags": [tag IDs] }`. On the sandbox host, the SDK resolves those IDs to
  the names required on that wire. Replacement accepts an empty list; append
  requires at least one ID.
- `CreateFieldPayload`: required `type`, `name`, and `is_required`; optional
  `regex`. `is_active` is omitted when true and sent as `false` when disabled.
- `UpdateFieldPayload`: partial `type`, `name`, `regex`, `is_required`, and
  `is_active`; `clearsRegex: true` sends `regex: null`.
- `FieldListParams`: `include_inactive` and `include_standard` Booleans.
- `FieldValidateMultipleItem`: `field_id` plus string `value`.
- `FieldJSONValidationItem`: `field_id` plus lossless `JSONValue`.
- `WebhookRegisterPayload`: required `url`, `email`, `events`, and `is_active`.
  Omitted `events` at initialization uses `WebhookEventType.defaultEvents`.
  Registration requires an absolute HTTP or HTTPS URL without user information,
  a valid email, and no blank event names.
- `WebhookDispatchListParams`: positive `page` and `perPage`; optional `event`;
  `delivered` only when `hasDeliveredFilter`; positive Unix `from`/`to` only
  when `hasTimeFilter`.
- `ListParams`: positive `page` and `perPage`, nonempty `search` and `sort`, and
  sorted caller-defined `extra` entries. Each operation table states which of
  these values belongs to that route.

## `JSONValue`

`JSONValue` is a public, `Codable`, `Sendable`, and `Equatable` lossless JSON
container. Construct it with one of these `JSONValue.Storage` cases:

```swift
let count = JSONValue(.integer(42))
let unsigned = JSONValue(.unsignedInteger(42))
let ratio = JSONValue(.number(0.5))
let enabled = JSONValue(.bool(true))
let object = JSONValue(.object([
    "label": JSONValue(.string("Example")),
    "values": JSONValue(.array([count, ratio])),
]))
let empty = JSONValue(.null)
```

The storage cases are `string(String)`, `integer(Int64)`,
`unsignedInteger(UInt64)`, `number(Double)`, `bool(Bool)`,
`object([String: JSONValue])`, `array([JSONValue])`, and `null`. Codable
round-trips the corresponding JSON type. `stringValue` returns strings
unchanged, formats scalar values, serializes objects/arrays as JSON, and maps
`null` to the empty string. Prefer the typed JSON properties described below;
their legacy views use this conversion.

## Response model schemas

The following catalog is shared by the operation tables above. Names are JSON
wire names; `?` means nullable or conditionally present.

### Authentication schemas

- `AuthSession`: `access_token: string`, `user: AuthUser`,
  `accounts: [AuthAccount]`.
- `AuthUser`: `id: string`, `name: string`, `email: string`, `telephone?: string`,
  `government_id?: string`, `is_email_verified: boolean`,
  `has_accepted_terms: boolean`, `created_at: date-time`,
  `to_be_deleted_at?: date-time`. The SDK also tolerates the legacy optional
  `is_password_set` field.
- `AuthAccount`: `id: string`, `name: string`, `roles: [string]`,
  `is_delete_allowed: boolean`, `created_at: date-time`.
- `NotificationPreferences`: the nine required Boolean keys listed in the
  authentication section.
- `ApiKey`: `api_key?: string`.
- `EmailResponse`: `email: string`.
- `SelfResponse` is the compatibility view containing `user: User` and
  `accounts: [Account]`; the direct v1 user response is exposed by
  `currentUserProfile()`.

### Account and statistics schemas

- `Account`: `resource: string`, `id: string`, `name: string`,
  `primary_color?: string`, `secondary_color?: string`,
  `notification_sender_type: User|Account`, `roles: [string]`,
  `is_delete_allowed: boolean`, `created_at: date-time`.
- `AccountTheme`: `account_name: string`, `primary_color: string`,
  `secondary_color?: string`, `logo: URL string`.
- `WorkspaceDeletionRestriction`: `code: ActivePaidSubscription|PendingDocuments`,
  `message: string`, `account_ids: [string]` from a failed delete envelope.
- `DocumentStatsRow`: `period: YYYY-MM|YYYY-MM-DD`,
  `documents_uploaded: integer`, `documents_sent: integer`,
  `signature_requests: integer`,
  `signature_requests_notification_bypass: integer`,
  `signature_requests_notification_email: integer`,
  `signature_requests_notification_whatsapp: integer`,
  `signature_requests_verification_bypass: integer`,
  `signature_requests_verification_email: integer`,
  `signature_requests_verification_whatsapp: integer`,
  `signature_requests_verification_digital_certificate: integer`,
  `signature_requests_viewed: integer`,
  `signature_requests_completed: integer`, and
  `documents_certified: integer`.

Notification channel totals can exceed `signature_requests` when more than one
channel was used. The four verification counters add to `signature_requests`.

### Signer schemas

- `Signer`: `resource?: string`, `id: string`, `full_name: string`,
  `email?: string`, `whatsapp_phone_number?: string`,
  `has_accepted_terms: boolean`.
- `SignerSelf`: all `Signer` fields plus `has_signature: boolean`,
  `has_initial: boolean`, `is_signature_reusable: boolean`.
- `AcceptTermsResponse` is a source-compatible SDK view with `full_name`,
  `email`, and `has_accepted_terms`; the canonical bare response has no data,
  so the SDK synthesizes empty strings and `true`.
- `AssignmentSigner`: all `Signer` fields plus
  `verification_method?: string`, `notification_methods?: [string]`,
  `step?: integer`, `notified?: boolean`, `completed?: boolean`, and
  `notification_history?: [NotificationHistoryEntry]`.
- `NotificationHistoryEntry`: `event: string`, `status: sent|failed`,
  `error_code?: string`, `error_message?: string`, `sent_at?: date-time`,
  `failed_at?: date-time`.

### Document schemas

- `Document`: `resource?: string`, `id: string`, `account_id: string`,
  `template_id?: string`, `name: string`, `status: string`,
  `artifacts: DocumentArtifacts`, `is_closed: boolean`,
  `signing_url: string`, `decline_reason?: string`, `declined_by?: Signer`,
  `tags: [{id: string, name: string}]`, `assignment?: Assignment`,
  `pages: [DocumentPage]`, `created_at: date-time`, `updated_at: date-time`.
- `DocumentArtifacts`: URL strings keyed by `original`, `thumbnail?`,
  `certificated?`, `certificate-page?`, `pades?`, and `bundle?`.
- `DocumentPage`: `id: string`, `number: integer`, `height: integer`,
  `width: integer`, `download_url: URL string`.
- `DocumentActivity`: `id: integer`, `event: string`, `message: string`,
  `payload?: object`, `origin?: {ip: string, user-agent: string}`,
  `created_at: date-time`. Swift callers receive lossless `payloadJSON` and
  `originJSON` values. The `payload` and `origin` properties are compatibility
  strings produced by `JSONValue.stringValue`.
- `DocumentVerification`: `hash: string`, `id?: string`, `status?: string`,
  `page_count?: string`, `signer_count?: string`, `completed_count?: integer`,
  `completed_at?: date-time`, `verified_at: date-time`, `is_valid: boolean`,
  `message: string`. Unknown or invalid hashes return `is_valid: false` with
  the document-specific fields null.
- `DocumentStatus`: `code: string`, `deletable: boolean`.
- `SigningProgress` is SDK-derived, not a wire payload: `signed: integer`,
  `total: integer`, `pending: integer`, `percentage: number`.
- `SendTokenResponse` is SDK-derived after the bare send response:
  `document: PublicDocumentInfo`, `channel: string`, `recipient: string`.

`DocumentUploadResponse` and `DocumentDetails` expose the full documented
`declined_by` signer as `declinedBySigner`. Their `declinedBy` property remains
a compact `DeclinedBySigner(id:fullName:email:)` compatibility projection.
`DocumentListItem` and `PublicDocumentInfo` expose the full signer directly as
`declinedBy`.

`PublicDocumentInfo`, `DocumentDetails`, `DocumentUploadResponse`, and
`DocumentListItem` are typed views of the `Document` wire object. They preserve
the rich pages, assignment, artifacts, tags, decline, lifecycle, and timestamp
fields instead of reducing the public response to a summary. Compatibility-only
fields such as `downloadUrl`, `downloadFinalUrl`, `createdBy`, or a derived
`pageCount` are optional and may be absent.

### Assignment and cost schemas

- `Assignment`: `resource: string`, `id: string`, `sender_email: string`,
  `method: virtual|collect`, `expires_at?: date-time`, `message?: string`,
  `signers: [AssignmentSigner]`, `copy_receivers: [Signer-compatible object]`,
  `items: [AssignmentItem]`, `summary: AssignmentSummary`,
  `signing_urls: [SigningUrl]`.
- `AssignmentItem`: `id: string`, `page?: DocumentPage`, `signer: object`,
  `field?: Field`, `display_settings?: DisplaySettings|legacy value`,
  `value?: any`, `completed: boolean`. Swift callers receive lossless
  `valueJSON`; `value` is its compatibility string view.
- `AssignmentSummary`: `signer_count: integer`, `completed_count: integer`,
  `signers: [Signer-compatible object]`.
- `SigningUrl`: `signer_id: string`, `url: URL string`.
- `DisplaySettings`: required numeric `left`, `top`, `width`, `height`,
  `fontSize`; optional string `fontFamily`, `backgroundColor`.
- `ResendNotificationResponse`: `is_sent: boolean`, `document_id: string`,
  `signer_id: string`.
- `WhatsappNotification`: `sent_at: integer` Unix timestamp,
  `header: string`, `body: string`, `buttons: [{text: string}]`,
  `phone_number: string`, `signer_id: string`.
- `CostEstimate`: `documents: integer`, `credits: number`,
  `needs_extra_document: boolean`, `extra_document_cost: number`,
  `total_credits: number`, `breakdown: [CostEstimateBreakdownItem]`,
  `document_balance: number`, `credit_balance: number`,
  `has_sufficient_resources: boolean`,
  `blocking_reason?: PendingPayment|InsufficientDocuments|InsufficientCredits`,
  `message?: string`.
- `CostEstimateBreakdownItem`: `code: string`, `name: string`, `cost: number`,
  `quantity: integer`, `unit_cost: number`.

`CostEstimate.documentCount` is the integer projection of the current
`documents` field. The `documents: Double`, `estimatedCost`,
`hasSufficientBalance`, and `raw` properties remain available for compatible
payloads. Current decisions should use `documentCount`,
`hasSufficientResources`, and `blockingReason`.

### Template and tag schemas

- `Template`: `resource: string`, `id: string`, `name: string`,
  `document_name?: string`, `message?: string`, `status: string`,
  `pages: [TemplatePage]`, `roles: [TemplateRole]`,
  `tags: [{id: string, name: string}]`,
  `default_document_tags: [{id: string, name: string}]`,
  `created_at: date-time`, `updated_at: date-time`.
- `TemplatePage`: `id: string`, `number: integer`, `height: integer`,
  `width: integer`, `download_url: URL string`,
  `fields: [TemplateFieldPlacement]`.
- `TemplateFieldPlacement`: `id: string`, `field_id: string`,
  `role_id: string`, `label: string`, `display_settings: any`,
  `created_at: date-time`, `updated_at: date-time`. Swift callers receive
  lossless `displaySettingsJSON`; `displaySettings` is its compatibility string
  view.
- `TemplateRole`: `id: string`, `name: string`, `assignment_type: string`,
  `created_at: date-time`, `updated_at: date-time`.
- `Tag`: `resource: string`, `id: string`, `name: string`, `color?: string`,
  `created_at: date-time`, `updated_at: date-time`.

Template list items may omit `default_document_tags`; compatible single-template
responses can include them. The SDK also tolerates optional `account_id` fields.

### Field schemas

- `Field`: `resource: string`, `id: string`, `name: string`, `type: string`,
  `regex?: string`, `is_pre_defined: boolean`, `is_active: boolean`,
  `is_required: boolean`, `is_standard: boolean`, `is_read_only: boolean`,
  `is_visible: boolean`.
- `FieldValidation`: `type: string`, `success: boolean`,
  `error_message: string`; validate-multiple results additionally contain
  `field_id: string`.
- `FieldType`: `type: string`, `name: string`.
- `FieldValidateMultipleItem`: `field_id: string`, `value: string`.
- `FieldJSONValidationItem`: `field_id: string`, `value: JSONValue`.

### Webhook schemas

- `WebhookSubscription`: `events: [string]`, `is_active: boolean`,
  `url?: URL string`, `email?: string`, `updated_at?: date-time`. The SDK also
  tolerates extension/legacy `id` and `created_at` fields.
- `WebhookEventType`: `id: string`, `description: string`.
- `WebhookDispatch`: `resource: string`, `id: string`, `event: string`,
  `activity_id: integer`, `endpoint?: URL string`, `payload?: object`,
  `delivered: boolean`, `http_status?: integer`, `response_body?: string`,
  `error?: string`, `created_at: date-time`, `updated_at: date-time`.
  `payloadJSON` is the lossless Swift value; `payload` is a Foundation
  dictionary compatibility view. `httpStatusCode` preserves a missing/null
  status; deprecated `httpStatus` maps it to zero.

## Shared public utilities and enums

- `PaginatedResult<T>(data:meta:)` stores a result array and optional
  `PaginationMeta`. Its `currentPage`, `lastPage`, `perPage`, and `total`
  properties are decoded from response headers by SDK list methods.
- `Logger` requires `debug(_:context:)`, `info(_:context:)`,
  `warn(_:context:)`, and `error(_:context:)`, each with a message and
  `[String: Any]` context. Protocol-extension overloads `debug(_:)`,
  `info(_:)`, `warn(_:)`, and `error(_:)` supply an empty context.
  `NoopLogger()` implements all four by discarding the event.
- `AssignmentMethod` maps `.virtual` / `.collect` to `virtual` / `collect`.
  `init(string:)` treats only `collect` as collect and otherwise returns
  virtual.
- `DocumentArtifactName` path values are `original`, `certificated`,
  `certificate-page`, `pades`, and `bundle`.
- `SignatureType` path/query values are `signature` and `initial`.
- `SendTokenChannel` values are `.email` and `.whatsapp`.
- `NotificationSenderType.user` and `.account` encode `User` and `Account`.
- `DocumentStatus` maps `uploading`, `uploaded`, `metadata_processing`,
  `metadata_ready`, `pending_signature`, `expired`, `certificating`,
  `certificated`, `rejected_by_signer`, `rejected_by_user`, and `failed`.
  Unknown strings decode to `.unknown`; `stringValue` performs the reverse
  mapping.
- `WebhookEventType` provides constants for `document_uploaded`,
  `document_metadata_ready`, `document_prepared`, `assignment_created`,
  `document_ready`, `signature_requested`, `signer_created`,
  `signer_email_verified`, `signer_whatsapp_verified`,
  `signer_data_confirmed`, `signer_viewed_document`,
  `signer_signed_document`, `signer_rejected_document`,
  `user_rejected_document`, `document_processing_failed`, `template_created`,
  `template_processed`, and `template_processing_failed`. `defaultEvents`
  contains document ready/prepared, signer signed/rejected, and document
  processing failed.

## High-level and transport async methods

`client.uploadAndRequestSignatures(documentData:options:accountId:)` is a
sequential convenience workflow, not a server-side transaction. It validates
that at least one signer exists and validates every signer name/email before any
upload, then:

1. calls `documents.upload`;
2. calls `documents.waitUntilReady`;
3. creates or reuses each signer one at a time; and
4. calls `assignments.create` with a virtual assignment.

It returns `(document: DocumentUploadResponse, assignment: Assignment)`. There
is no rollback endpoint: a failure after upload can leave a document or signer
that the caller may choose to clean up.

`AssinafyClient.UploadOptions(signers:)` requires the signer array and exposes
mutable `message`, `expiresAt`, and `accountId` overrides.
`AssinafyClient.SignerInput(name:email:)` requires both values and exposes an
optional mutable `whatsappPhoneNumber`. The workflow rejects an empty signer
array, invalid names/emails, and duplicate case-insensitive emails before the
upload begins.

### Low-level request and transport API

`HTTPMethod` exposes `.get`, `.post`, `.put`, `.patch`, and `.delete`.
`APIRequest` is immutable and has these public constructors:

Request and response models with custom `Codable` behavior expose the standard
`encode(to:)` protocol witness. Callers normally use `JSONEncoder`; those
implementations produce the exact wire keys and compatibility rules in the
payload catalog above.

| Constructor | Result |
| --- | --- |
| `init(method:path:queryItems:body:contentType:)` | Raw request descriptor; defaults to no query/body, `application/json`, and `credential: .workspace`. |
| `init(method:path:queryItems:body:contentType:credential:)` | Same, with an explicit `APIRequest.Credential`. |
| `get(_:queryItems:)` | `GET` with optional query and no body. |
| `delete(_:queryItems:)` | `DELETE` with optional query and no body. |
| `delete(_:body:)` | `DELETE` with a JSON-encoded `Encodable` body. |
| `post(_:body:)` / `post(_:)` | `POST` with a JSON body or no body. |
| `put(_:body:)` / `put(_:)` | `PUT` with a JSON body or no body. |
| `put(_:body:queryItems:)` | `PUT` with both JSON body and query. |
| `patch(_:body:)` / `patch(_:)` | `PATCH` with a JSON body or no body. |

The generic body factories throw the underlying encoding error. JSON keys are
sorted for deterministic output. `APIResponse(data:headers:statusCode:)` stores
raw bytes, all response headers, and the HTTP status.

Every `APIRequest` carries an `APIRequest.Credential`, which decides whether the
transport may attach the workspace credential:

| Value | Meaning |
| --- | --- |
| `.workspace` | Send the configured `Authorization` or `X-Api-Key` header. The default for every constructor and factory. |
| `.withheld` | Send no workspace credential. |

`withoutWorkspaceCredential()` returns a copy with `.withheld` and every other field
unchanged. The SDK applies it to each operation the v1 OpenAPI document declares
as **Public** (`security: []`) or **Signer** (`security: [signerAccessCode]`) —
the operations marked Public or Signer in the tables above.

`HTTPClientProtocol.perform(_:)` is the public transport seam. The built-in
`URLSessionHTTPClient(baseURL:defaultHeaders:timeout:)` uses an ephemeral
session with cookies and URL caching disabled. Its initializer validates an
absolute HTTPS base URL without credentials/query/fragment and a finite,
positive timeout. `perform(_:)` resolves the request path against that base,
applies the default headers — withholding `Authorization` and `X-Api-Key`
(matched case-insensitively) when the request's credential is `.withheld` — returns
only 2xx responses, maps non-2xx responses to `APIError`, maps `URLError`
failures to `NetworkError`, and preserves transport cancellation as
`CancellationError`.

### Redirect policy

`urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)`
is the transport's public `URLSessionTaskDelegate` entry point and applies the
following policy.

Redirect destinations containing a username or password are always refused.
Other same-origin redirects preserve the redirected request. Origin equality
uses scheme, case-insensitive host, and effective port (`443` for HTTPS, `80`
for HTTP). A cross-origin redirect is accepted only when all of these are true:

- the destination is HTTPS;
- the redirected method is `GET` or `HEAD`; and
- there is no body or body stream.

For accepted cross-origin redirects the transport preserves only `Accept`,
`Accept-Encoding`, `Accept-Language`, `Range`, `If-Range`, and `User-Agent`
(case-insensitive). It strips `Authorization`, `Proxy-Authorization`,
`X-Api-Key`, `Cookie`, and every unknown custom header. HTTP downgrades,
credential-bearing destination URLs, and cross-origin body redirects are
refused.

## Errors

### API error payload

The v1 error envelope is:

```json
{
  "status": 400,
  "message": "Human-readable error message.",
  "data": null
}
```

`status` mirrors the HTTP status and `data` is a nullable object. Workspace
deletion can additionally include a top-level payload:

```json
{
  "status": 400,
  "message": "Cannot delete while restrictions are active.",
  "data": null,
  "restrictions": [
    {
      "code": "ActivePaidSubscription",
      "message": "Account has an active paid subscription.",
      "account_ids": ["account_example_001"]
    }
  ]
}
```

The OpenAPI response component called `ValidationError` is attached to `400`
operations even though that component's embedded status example is `422`.
Applications should use `APIError.statusCode`, which comes from the actual HTTP
response. The SDK's separate local `ValidationError` bridges to code `422` and
does not imply that the server returned HTTP 422.

Every v1 operation in the tables declares `500`. Every row marked Account or
Signer declares `401`. These are the additional declared statuses:

- `400`: `PUT /accounts/{accountId}`;
  `DELETE /accounts/{accountId}`;
  `POST /accounts/{accountId}/logo`; `POST /accounts`;
  `POST /documents/{documentId}/assignments`;
  `POST /documents/{documentId}/assignments/estimate-cost`;
  `PUT /documents/{documentId}/assignments/{assignmentId}/reset-expiration`;
  `POST /login`; `PUT /authentication/reset-password`;
  `PUT /authentication/change-password`;
  `POST /accounts/{accountId}/documents`; `PATCH /documents/{documentId}`;
  `POST /accounts/{accountId}/fields`;
  `PUT /users/self/notification-preferences`;
  `POST /accounts/{accountId}/signers`;
  `PUT /accounts/{accountId}/signers/{signerId}`; `GET /sign`;
  `POST /documents/{documentId}/assignments/{assignmentId}`; `POST /verify`;
  `POST /authentication/social-login`; `POST /auth/link-social-login`;
  `GET /accounts/{accountId}/stats`; `GET /users/self/stats`;
  `POST /accounts/{accountId}/tags`;
  `PUT /accounts/{accountId}/tags/{tagId}`;
  `POST /accounts/{accountId}/templates/{templateId}/documents`;
  `PUT /accounts/{accountId}/webhooks/subscriptions`; and
  `POST /accounts/{accountId}/webhooks/{historyId}/retry`.
- `404`: `GET /accounts/{accountId}`; `DELETE /accounts/{accountId}`;
  `GET /accounts/{accountId}/logo`;
  `PUT /documents/{documentId}/assignments/{assignmentId}/reset-expiration`;
  `GET /documents/{documentId}`; `DELETE /documents/{documentId}`;
  `PATCH /documents/{documentId}`;
  `GET /documents/{documentId}/download/{artifactName}`;
  `GET`, `PUT`, and `DELETE /accounts/{accountId}/fields/{fieldId}`;
  `GET /documents/{documentId}/thumbnail`;
  `GET /documents/{documentId}/pages/{pageId}/download`;
  `GET /public/documents/{documentId}`;
  `GET`, `PUT`, and `DELETE /accounts/{accountId}/signers/{signerId}`;
  `GET /signers/{signerId}/document`; `GET /signature/{signatureType}`;
  `GET /signers/{signerId}/documents/{documentId}/download/{artifactName}`;
  `PUT` and `DELETE /accounts/{accountId}/tags/{tagId}`; and
  `POST /accounts/{accountId}/webhooks/{historyId}/retry`.
- `409`: `GET /sign` while preparation is incomplete;
  `POST /documents/{documentId}/assignments/{assignmentId}` while the document
  is not ready; and `POST /accounts/{accountId}/tags` when the tag name exists.

Compatibility endpoints have no v1-declared status table. Any HTTP status
outside 200...299—including standard `403`, `415`, and `429` responses—is still
surfaced as `APIError`.

### Swift and Objective-C error types

| Swift error | When thrown | Important properties | `NSError` bridge |
| --- | --- | --- | --- |
| `APIError` | Non-2xx HTTP, or a response envelope whose `status` is outside 200...299 | `statusCode`, `message`, raw `responseData`, `context`, `workspaceDeletionRestrictions` | Domain `ASFErrorDomain.api`; code is HTTP status; `userInfo["responseData"]` when present. |
| `ValidationError` | Invalid local configuration, identifier, account resolution, payload, PDF/PNG bytes, or helper option | `message`, field-level `errors`, `context` | Domain `ASFErrorDomain.validation`; code `422`; `userInfo["errors"]`. |
| `NetworkError` | URL loading failed before a valid HTTP response, or response was not HTTP | `message`, `underlyingError` | Domain `ASFErrorDomain.network`; code is the underlying `URLError.Code`, otherwise `notConnectedToInternet`; includes `NSUnderlyingErrorKey`. |
| `AssinafySDKError` | Missing/undecodable success data, polling timeout/terminal state, failed post-delivery lookup, or another SDK contract failure | `message`, structured `context`, `underlyingError` | Domain `ASFErrorDomain.sdk`; code `-1`; context is merged into `userInfo`; includes `NSUnderlyingErrorKey` when present. |
| `CancellationError` | Swift task or URL loading cancellation | Standard Swift cancellation | Preserved without wrapping. |

The public constructors are
`APIError(statusCode:message:responseData:)`,
`ValidationError(_:errors:)`,
`NetworkError(_:underlyingError:)`, and
`AssinafySDKError(_:context:underlyingError:)`. All SDK-defined error types
conform to `AssinafyErrorProtocol`, which exposes `message` and `context`.

Typed methods require decodable success `data`; a successful envelope without
it throws `AssinafySDKError`. List methods require an array. `Void` methods
accept an empty or non-JSON 2xx body and reject a JSON envelope carrying a
non-2xx `status`. Binary methods return the 2xx bytes unchanged unless those
bytes are a JSON envelope carrying a non-2xx `status`, which becomes
`APIError`.

## Objective-C completion wrappers

Completion-handler methods are main-queue mirrors of their async counterparts;
they do not define different HTTP operations or payloads. Array-returning
wrappers unwrap list `data`; error-only wrappers discard the response body.
These are the explicit resource selectors:

| Resource | Completion selectors |
| --- | --- |
| Auth | `loginWithPayload:completion:`, `getAPIKeyWithCompletion:`, `createAPIKeyWithPayload:completion:`, `currentUserWithCompletion:`, `getNotificationPreferencesWithCompletion:`, `updateNotificationPreferences:completion:`, `statsWithParams:completion:`, `linkSocialLogin:completion:` |
| Workspaces | `createWorkspace:completion:`, `listWorkspacesWithCompletion:`, `getWorkspaceWithId:completion:`, `updateWorkspaceWithId:payload:completion:`, `deleteWorkspaceWithId:force:completion:`, `themeWithAccountId:completion:`, `statsWithParams:accountId:completion:`, `downloadLogoWithAccountId:completion:`, `uploadLogo:filename:contentType:accountId:completion:`, `deleteLogoWithAccountId:completion:` |
| Signers | `createSigner:accountId:completion:`, `getSignerWithId:accountId:completion:`, `updateSignerWithId:payload:accountId:completion:`, `deleteSignerWithId:accountId:completion:`, `findSignerByEmail:accountId:completion:` |
| Documents | `uploadDocument:accountId:completion:`, `listDocumentsWithAccountId:completion:`, `getDocumentWithId:completion:`, `deleteDocumentWithId:completion:`, `renameDocumentWithId:name:completion:`, `searchDocumentsWithTerm:status:accountId:completion:` |
| Assignments | `listAssignmentsWithAccountId:completion:`, `createAssignmentForDocument:signerIds:completion:`, `resendNotificationForDocument:assignmentId:signerId:completion:` |
| Templates | `listTemplatesWithAccountId:completion:`, `getTemplateWithId:accountId:completion:`, `deleteTemplateWithId:accountId:completion:` |
| Tags | `listTagsWithAccountId:completion:`, `createTag:accountId:completion:`, `updateTagWithId:payload:accountId:completion:`, `deleteTagWithId:force:accountId:completion:` |
| Fields | `createField:accountId:completion:`, `listFieldsWithAccountId:completion:`, `getFieldWithId:accountId:completion:`, `deleteFieldWithId:accountId:completion:` |
| Webhooks | `registerWebhook:accountId:completion:`, `getWebhookWithAccountId:completion:`, `deleteWebhookWithAccountId:completion:`, `inactivateWebhookWithAccountId:completion:`, `inactivateWebhookAndReturnWithAccountId:completion:`, `listDispatchesWithAccountId:completion:` |

The explicitly named non-resource initializers are
`initWithAPIKey:token:baseURL:defaultAccountId:timeout:` on configuration,
`initWithType:name:regex:isRequired:isActive:clearsRegex:` on
`UpdateFieldPayload`,
`initWithFullName:email:whatsappPhoneNumber:governmentId:` on
`UpdateSignerPayload`, `initWithPage:perPage:` on
`SignerDocumentListParams`, and
`initWithStatus:search:tagIds:sort:page:perPage:` on `TemplateListParams`.

The client class is exported as `ASFAssinafyClient`. The generated header also
contains its configuration/client initializers and
`socialLoginAuthorizationURLWithAuthClient:`. `JSONValue`, the JSON-preserving
field-validation overloads, and the `originJSON`, `payloadJSON`, `valueJSON`,
and `displaySettingsJSON` properties are Swift-only (`@nonobjc`). Use their
documented compatibility views from Objective-C. The generated header remains
the source of truth for Swift-to-Objective-C type names and nullability.

## Live-test safety gates

The default test suite uses mocked transport and requires no credentials. Live
tests are opt-in and skip unless the host is exactly the HTTPS Assinafy sandbox
with no custom port, credentials, query, or fragment:

```sh
ASSINAFY_API_KEY="{sandbox-api-key}" \
ASSINAFY_ACCOUNT_ID="account_example_001" \
ASSINAFY_BASE_URL="https://sandbox.assinafy.com.br/v1" \
swift test --filter AssinafyTests.AssinafyLiveTests
```

Mutation tests remain skipped unless all of the following are also set:

```sh
ASSINAFY_RUN_LIVE_MUTATIONS=1 \
ASSINAFY_TEST_EMAIL_A="recipient-a@example.test" \
ASSINAFY_TEST_EMAIL_B="recipient-b@example.test"
```

Use two distinct controlled recipients. Never commit credentials, account IDs,
signer access codes, personal addresses, or captured API payloads.
The GitHub `Live Sandbox` workflow runs read-only checks weekly and the complete
mutation suite for `v*` tags or manual mutation runs. Complete CI runs set
`ASSINAFY_REQUIRE_LIVE_ASSIGNMENT=1`, so insufficient sandbox assignment
resources fail instead of skipping the release check.
