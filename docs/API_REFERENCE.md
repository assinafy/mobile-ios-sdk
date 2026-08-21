# Assinafy iOS SDK API reference

This reference maps every public Swift `async` SDK operation to the current
production API contract. The authoritative sources are the
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
- **Public** means the production OpenAPI operation declares no authentication.
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
- When the configured host is `sandbox.assinafy.com.br`, the client enables only
  the two live-proven sandbox request adaptations called out below. Production
  and custom hosts remain production-contract exact.

## Authentication and current user

All methods in this section are available through `client.auth`.

| Async SDK method | Auth | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `login(_:)` | Public | `POST /login`; JSON `email` and `password`, both required | `data: AuthSession` -> `LoginResponse` |
| `socialLogin(_:)` | Public | `POST /authentication/social-login`; JSON `provider` (`google`), `token`, and `has_accepted_terms`, all required | `data: AuthSession` -> `LoginResponse` |
| `linkSocialLogin(_:)` | Account | `POST /auth/link-social-login`; JSON `provider` (`google`) and `token`, both required | Bare envelope; returns `Void` |
| `currentUser()` | Account | `GET /users/self` | `data` is a direct `AuthUser`, normalized to `SelfResponse(user: data, accounts: [])`. The decoder also accepts the former `{user, accounts}` data wrapper. |
| `getNotificationPreferences()` | Account | `GET /users/self/notification-preferences` | `data: NotificationPreferences` |
| `updateNotificationPreferences(_:)` | Account | `PUT /users/self/notification-preferences`; partial `NotificationPreferences` JSON; at least one key is required by the SDK | The complete updated `NotificationPreferences` |
| `stats(params:)` | Account | `GET /users/self/stats`; optional `granularity=monthly|daily`, `month=YYYY-MM` | `[DocumentStatsRow]` |
| `changePassword(_:)` | Account | `PUT /authentication/change-password`; required JSON `email`, `password`, `new_password` | Documented `data.email`; SDK returns `Void` |
| `requestPasswordReset(_:)` | Public | `PUT /authentication/request-password-reset`; required JSON `email` | Documented `data.email`; SDK returns `Void` |
| `resetPassword(_:)` | Public | `PUT /authentication/reset-password`; required JSON `email`, `new_password`; optional `token` | Documented `data.email`; SDK returns `Void` |
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
| `create(_:)` | `POST /accounts`; required JSON `name`; optional `notification_sender_type=User|Account` | `data: Account` -> `WorkspaceResponse` |
| `list(params:)` | `GET /accounts`; no query is emitted | `[Account]` -> `PaginatedResult<WorkspaceListItem>` |
| `get(workspaceId:)` | `GET /accounts/{workspaceId}` | `Account` -> `WorkspaceResponse` |
| `update(workspaceId:payload:)` | `PUT /accounts/{workspaceId}`; partial JSON `name`, `notification_sender_type=User|Account` | Updated `Account` |
| `delete(workspaceId:force:)` | `DELETE /accounts/{workspaceId}`; JSON `force: boolean` | Documented `data: []`; returns `Void` |
| `theme(accountId:)` | `GET /accounts/{accountId}/theme` | `AccountTheme` |
| `stats(params:accountId:)` | `GET /accounts/{accountId}/stats`; optional `granularity=monthly|daily`, `month=YYYY-MM` | `[DocumentStatsRow]` |
| `downloadLogo(accountId:)` | `GET /accounts/{accountId}/logo` | Raw image `Data` |
| `uploadLogo(_:filename:contentType:accountId:)` | `POST /accounts/{accountId}/logo`; multipart field `file` is required | Bare envelope; returns `Void` |
| `deleteLogo(accountId:)` | `DELETE /accounts/{accountId}/logo` | Bare envelope; returns `Void` |

The production `GET /accounts` contract declares no query parameters. The
`ListParams` argument remains source-compatible but the SDK intentionally ignores
it; sandbox checks found account-list search, pagination, and sort were ignored.

## Signers

Workspace management methods require account auth. Signer-facing methods use the
signer code exactly where shown.

| Async SDK method | Auth | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `create(_:accountId:)` | Account | `POST /accounts/{accountId}/signers`; required `full_name`; optional `email`, `whatsapp_phone_number` | `Signer`. If `email` is present, the SDK first searches and reuses an exact case-insensitive match. Full-name-only creation is supported. |
| `get(signerId:accountId:)` | Account | `GET /accounts/{accountId}/signers/{signerId}` | `Signer` |
| `list(params:accountId:)` | Account | `GET /accounts/{accountId}/signers`; optional `search`, `page`, `per-page` | `PaginatedResult<Signer>`. Do not set generic `sort` or `extra`; they are not in this operation's production contract. |
| `update(signerId:payload:accountId:)` | Account | `PUT /accounts/{accountId}/signers/{signerId}`; partial `full_name`, `email`, `whatsapp_phone_number`, `government_id` | Updated `Signer` |
| `delete(signerId:accountId:)` | Account | `DELETE /accounts/{accountId}/signers/{signerId}` | Documented `data: []`; returns `Void` |
| `findByEmail(_:accountId:)` | Account | Helper over signer list with `search={email}&per-page=100`; filters returned emails case-insensitively | Matching `Signer?`; a 404 becomes `nil` |
| `getSelf(signerAccessCode:)` | Signer | `GET /signers/self?signer-access-code={code}` | `SignerSelf` -> `SignerSelfInfo` |
| `acceptTerms(signerAccessCode:)` | Signer | `PUT /signers/accept-terms?signer-access-code={code}`; no JSON body | Bare envelope. The source-compatible `AcceptTermsResponse` is synthesized as `fullName: ""`, `email: ""`, `hasAcceptedTerms: true`; a legacy response body is still decoded. |
| `verifyEmail(payload:)` | Signer | `POST /verify?signer-access-code={code}`; JSON contains only `verification-code` | Bare envelope; returns `Void`. `signerAccessCode` is never emitted in the body. |
| `uploadSignature(signerAccessCode:type:imageData:reuse:)` | Signer | `POST /signature?signer-access-code={code}&type=signature|initial[&reuse=true]`; body is PNG bytes (`image/png`) | Bare envelope; returns `Void` |
| `downloadSignature(signerAccessCode:type:)` | Signer | `GET /signature/{signatureType}?signer-access-code={code}` where the path value is `signature` or `initial` | Raw image `Data`; there is no redundant `type` query |
| `getCurrentDocument(signerId:signerAccessCode:)` | Signer | `GET /signers/{signerId}/document?signer-access-code={code}` | `Document`; the API omits pages and limits assignment items to this signer |
| `listSignerDocuments(signerId:signerAccessCode:params:)` | Signer | `GET /signers/{signerId}/documents?signer-access-code={code}`; production documents optional `page`, `per-page`; the SDK also forwards compatibility `status`, `method`, `search`, `sort` | `PaginatedResult<DocumentDetails>` |
| `searchSignerDocuments(signerId:signerAccessCode:search:status:)` | Signer | `GET /signers/{signerId}/documents/search?signer-access-code={code}`; production documents optional `search`; the SDK also forwards compatibility `status` | `PaginatedResult<DocumentDetails>` |
| `signMultipleDocuments(signerAccessCode:documentIds:)` | Signer | `PUT /signers/documents/sign-multiple?signer-access-code={code}`; JSON `document_ids: [string]`, nonempty | Bare envelope; returns `Void` |
| `declineMultipleDocuments(signerAccessCode:documentIds:reason:)` | Signer | `PUT /signers/documents/decline-multiple?signer-access-code={code}`; JSON `document_ids: [string]`, `decline_reason: string` | Bare envelope; returns `Void` |
| `downloadSignerDocumentArtifact(signerId:documentId:artifact:)` | Public | `GET /signers/{signerId}/documents/{documentId}/download/{artifact}` | Raw PDF `Data` |
| `downloadSignerDocumentArtifact(signerId:documentId:artifact:signerAccessCode:)` | Public | Compatibility overload of the preceding operation; the supplied code is intentionally not sent | Raw PDF `Data` |
| `getSigningDocument(signerAccessCode:hasAcceptedTerms:)` | Signer | `GET /sign?signer-access-code={code}`; optional `has_accepted_terms=true|false` | `DocumentDetails` |

Signer document and account document artifact path values are `original`,
`certificated`, `certificate-page`, `pades`, and `bundle`.

The signer-document `status`, `method`, and `sort` filters (and `status` on the
search endpoint) are undocumented compatibility extensions. They remain emitted
to preserve existing integrations because signer credentials were unavailable
for a safe, non-mutating support check; callers that require production-OpenAPI
portability should use only the documented pagination/search parameters.

## Documents

Unless marked public, document operations require account auth.

| Async SDK method | Auth | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `upload(_:options:)` | Account | `POST /accounts/{accountId}/documents`; multipart required `file` containing a PDF | `Document` -> `DocumentUploadResponse`. The SDK validates PDF magic bytes and the 25 MB limit first. |
| `list(params: ListParams, accountId:)` | Account | `GET /accounts/{accountId}/documents`; optional `page`, `per-page`, `search`, `sort` | `PaginatedResult<DocumentListItem>` |
| `list(params: DocumentListParams, accountId:)` | Account | Same path; optional `status`, `method=virtual|collect`, `search`, `tags` (comma-separated tag IDs), `sort`, `page`, `per-page` | `PaginatedResult<DocumentListItem>` |
| `search(search:status:accountId:)` | Account | `GET /accounts/{accountId}/documents/search`; optional `search`, `status` | Lightweight `PaginatedResult<DocumentListItem>`; preserved source-compatible overload |
| `search(search:status:page:perPage:accountId:)` | Account | Same path; optional `search`, `status`; required Swift pagination arguments below `1` are omitted, otherwise emit `page`, `per-page` | Same result |
| `get(documentId:)` | Account | `GET /documents/{documentId}` | `Document` -> `DocumentDetails` |
| `rename(documentId:name:)` | Account | `PATCH /documents/{documentId}`; JSON `{ "name": string }` | Updated `DocumentDetails` |
| `waitUntilReady(documentId:options:)` | Account | Local polling helper over `GET /documents/{documentId}` | Returns `DocumentUploadResponse` at `metadata_ready`, `pending_signature`, `certificating`, or `certificated`; throws on `failed` or timeout |
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
| `sendPublicSignToken(documentId:payload:)` | Public | `PUT /public/documents/{documentId}/send-token`; production/custom hosts send `{ "email": string }` for the default email channel | Bare envelope, then SDK performs `GET /public/documents/{documentId}` and returns `SendTokenResponse(document, channel, recipient)` |
| `confirmSignerData(documentId:signerAccessCode:payload:)` | Signer | `PUT /documents/{documentId}/signers/confirm-data?signer-access-code={code}`; production body may contain `full_name`, `email`, `government_id` | Documented `Signer` response is discarded to preserve the SDK's `Void` result |

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

The production send-token body documents email delivery only. On the configured
Assinafy sandbox host, the SDK also emits the live-required `recipient` and
`channel`; those compatibility fields are absent from production OpenAPI. A
non-default `.whatsapp` payload also emits `channel` on custom hosts. Likewise,
the SDK emits `ConfirmSignerDataPayload.whatsappPhoneNumber` when present and
always emits `has_accepted_terms`; those two keys are undocumented compatibility
extensions, not production-OpenAPI confirmation fields.

## Assignments

Owner operations require account auth. Signing and decline operations require
signer auth.

| Async SDK method | Auth | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `list(params:accountId:)` | Account | `GET /assignments`; optional `page`, `per-page`; production/custom hosts omit `accountId` unless explicitly passed; the Assinafy sandbox host uses the explicit or default ID | `PaginatedResult<Assignment>` |
| `create(documentId:payload:)` | Account | `POST /documents/{documentId}/assignments`; exact body below | `Assignment` |
| `estimateCost(documentId:payload:)` | Account | `POST /documents/{documentId}/assignments/estimate-cost`; exact estimate body below | `CostEstimate` |
| `resetExpiration(documentId:assignmentId:expiresAt:)` | Account | `PUT /documents/{documentId}/assignments/{assignmentId}/reset-expiration`; JSON `{ "expires_at": string|null }` | Updated `Assignment` |
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

Production documents only `page` and `per-page`; leave generic
`ListParams.search`, `sort`, and `extra` unset. The sandbox was live-verified to
require camel-case `accountId` (no ID returned 400, a matching ID returned 200,
and an unknown ID returned 404), so clients configured for that host add the
explicit or default account ID. Production/custom-host calls omit it unless the
caller explicitly supplies the compatibility argument.

## Templates

All template methods require account auth.

| Async SDK method | Contract status | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `list(params: ListParams, accountId:)` | Production operation plus compatibility queries | `GET /accounts/{accountId}/templates`; production documents `search`, `page`, `per-page`; generic `ListParams` also forwards nonempty `sort` and `extra` | `PaginatedResult<TemplateListItem>` |
| `list(params: TemplateListParams, accountId:)` | Production operation plus compatibility queries | Same path; production documents `search`, `page`, `per-page`; SDK also forwards `status`, comma-separated tag IDs as `tags`, and `sort` | Same result |
| `create(name:pdfData:accountId:)` | **Live-verified sandbox extension; absent from production OpenAPI** | `POST /accounts/{accountId}/templates`; multipart `name` and PDF `file` | `TemplateDetails` |
| `get(templateId:accountId:)` | **Live-verified sandbox extension; absent from production OpenAPI** | `GET /accounts/{accountId}/templates/{templateId}` | `TemplateDetails` |
| `update(templateId:payload:accountId:)` | **Live-verified sandbox extension; absent from production OpenAPI** | `PUT /accounts/{accountId}/templates/{templateId}`; partial JSON `name`, `document_name`, `message` | Updated `TemplateDetails` |
| `delete(templateId:accountId:)` | **Live-verified sandbox extension; absent from production OpenAPI** | `DELETE /accounts/{accountId}/templates/{templateId}` | Returns `Void` |

For strict production-OpenAPI behavior set only `search`, `page`, and `perPage`.
`status` and `tags` are live-verified sandbox extensions absent from production
OpenAPI. `sort` is retained as a legacy compatibility query but is not asserted
as production-supported; generic `extra` keys are caller-defined and likewise
outside the production contract.

## Tags

All tag methods require account auth.

| Async SDK method | Exact request | Wire response and SDK result |
| --- | --- | --- |
| `list(params:accountId:)` | `GET /accounts/{accountId}/tags`; optional `search` | `PaginatedResult<Tag>` |
| `create(_:accountId:)` | `POST /accounts/{accountId}/tags`; required `name`; optional nullable `color` (six hex digits, with or without input `#`) | `Tag` |
| `update(tagId:payload:accountId:)` | `PUT /accounts/{accountId}/tags/{tagId}`; partial `name`, nullable `color`; `clearsColor` sends `color: null` | Updated `Tag` |
| `delete(tagId:force:accountId:)` | `DELETE /accounts/{accountId}/tags/{tagId}`; optional query `force=true` | Documented `data.deleted: boolean`; SDK returns `Void` |
| `listDocumentTags(documentId:accountId:)` | `GET /accounts/{accountId}/documents/{documentId}/tags` | `[Tag]` |
| `replaceDocumentTags(documentId:tagIds:accountId:)` | `PUT` to the preceding collection; JSON `{ "tags": [tag IDs] }`; an empty array removes all | `[Tag]` |
| `replaceDocumentTags(documentId:tagNames:accountId:)` | Deprecated label-only overload; values are still tag IDs and it forwards unchanged | `[Tag]` |
| `appendDocumentTags(documentId:tagIds:accountId:)` | `POST` to the document tag collection; JSON `{ "tags": [tag IDs] }`, nonempty | `[Tag]` |
| `appendDocumentTags(documentId:tagNames:accountId:)` | Deprecated label-only overload; values are still tag IDs and it forwards unchanged | `[Tag]` |
| `detachDocumentTag(documentId:tagId:accountId:)` | `DELETE /accounts/{accountId}/documents/{documentId}/tags/{tagId}` | Documented `data: []`; returns `Void` |

Except for template-document creation as called out above, tag attachment values
are tag IDs, not tag names.

## Fields

The production OpenAPI declares account auth for every field operation.

| Async SDK method | Exact production request | Wire response and SDK result |
| --- | --- | --- |
| `create(_:accountId:)` | `POST /accounts/{accountId}/fields`; required `name`, `type`; optional `regex`, `is_required` | `Field` -> `FieldDefinition` |
| `list(params:accountId:)` | `GET /accounts/{accountId}/fields`; optional `include_inactive`, `include_standard` | `PaginatedResult<FieldDefinition>` |
| `get(fieldId:accountId:)` | `GET /accounts/{accountId}/fields/{fieldId}` | `FieldDefinition` |
| `update(fieldId:payload:accountId:)` | `PUT /accounts/{accountId}/fields/{fieldId}`; partial `name`, nullable `regex`, `is_active` | Updated `FieldDefinition` |
| `delete(fieldId:accountId:)` | `DELETE /accounts/{accountId}/fields/{fieldId}` | Documented `data: []`; returns `Void` |
| `validate(fieldId:value:signerAccessCode:accountId:)` | `POST /accounts/{accountId}/fields/{fieldId}/validate`; required JSON `value` | `FieldValidationResult` |
| `validateMultiple(items:signerAccessCode:accountId:)` | `POST /accounts/{accountId}/fields/validate-multiple`; nonempty top-level array of `{field_id, value}` | `[FieldValidationResult]`; each item also carries `field_id` |
| `listFieldTypes()` | `GET /field-types` | `[FieldTypeInfo]` |

The SDK retains the following **live-verified sandbox extensions absent from the
production OpenAPI**:

- Create sends `is_active: false` when requested; `true` is omitted as the
  documented default.
- Update may send `type` and `is_required`. `clearsRegex` is not an extension:
  it sends the production-documented `regex: null`.
- `validate` and `validateMultiple` may append
  `signer-access-code={code}`. Production documents account auth only.

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

## Complete production wire schemas

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

### Account and statistics schemas

- `Account`: `resource: string`, `id: string`, `name: string`,
  `primary_color?: string`, `secondary_color?: string`,
  `notification_sender_type: User|Account`, `roles: [string]`,
  `is_delete_allowed: boolean`, `created_at: date-time`.
- `AccountTheme`: `account_name: string`, `primary_color: string`,
  `secondary_color?: string`, `logo: URL string`.
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
Both stats endpoints are production-only in the current contract; the sandbox
may return 404.

### Signer schemas

- `Signer`: `resource?: string`, `id: string`, `full_name: string`,
  `email?: string`, `whatsapp_phone_number?: string`,
  `has_accepted_terms: boolean`.
- `SignerSelf`: all `Signer` fields plus `has_signature: boolean`,
  `has_initial: boolean`, `is_signature_reusable: boolean`.
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
  `created_at: date-time`. The SDK preserves variable `payload` and `origin`
  content as JSON strings.
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

`PublicDocumentInfo`, `DocumentDetails`, `DocumentUploadResponse`, and
`DocumentListItem` are typed views of the `Document` wire object. They preserve
the rich pages, assignment, artifacts, tags, decline, lifecycle, and timestamp
fields instead of reducing the public response to a summary. Compatibility-only
fields such as `downloadUrl`, `downloadFinalUrl`, `createdBy`, or a derived
`pageCount` may be absent from the production wire payload.

### Assignment and cost schemas

- `Assignment`: `resource: string`, `id: string`, `sender_email: string`,
  `method: virtual|collect`, `expires_at?: date-time`, `message?: string`,
  `signers: [AssignmentSigner]`, `copy_receivers: [Signer-compatible object]`,
  `items: [AssignmentItem]`, `summary: AssignmentSummary`,
  `signing_urls: [SigningUrl]`.
- `AssignmentItem`: `id: string`, `page?: DocumentPage`, `signer: object`,
  `field?: Field`, `display_settings?: DisplaySettings|legacy value`,
  `value?: any`, `completed: boolean`.
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
- `CostEstimate`: `documents: number`, `credits: number`,
  `needs_extra_document: boolean`, `extra_document_cost: number`,
  `total_credits: number`, `breakdown: [CostEstimateBreakdownItem]`,
  `document_balance: number`, `credit_balance: number`,
  `has_sufficient_resources: boolean`,
  `blocking_reason?: PendingPayment|InsufficientDocuments|InsufficientCredits`,
  `message?: string`.
- `CostEstimateBreakdownItem`: `code: string`, `name: string`, `cost: number`,
  `quantity: integer`, `unit_cost: number`.

For compatibility with older cost payloads, `CostEstimate` also exposes
`estimatedCost`, `hasSufficientBalance`, and the raw decoded object. Current
decisions should use `hasSufficientResources` and `blockingReason`.

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
  `created_at: date-time`, `updated_at: date-time`.
- `TemplateRole`: `id: string`, `name: string`, `assignment_type: string`,
  `created_at: date-time`, `updated_at: date-time`.
- `Tag`: `resource: string`, `id: string`, `name: string`, `color?: string`,
  `created_at: date-time`, `updated_at: date-time`.

The production template list omits `default_document_tags`; the single-template
extension returns them. The SDK tolerates older optional `account_id` template
fields.

### Field schemas

- `Field`: `resource: string`, `id: string`, `name: string`, `type: string`,
  `regex?: string`, `is_pre_defined: boolean`, `is_active: boolean`,
  `is_required: boolean`, `is_standard: boolean`, `is_read_only: boolean`,
  `is_visible: boolean`.
- `FieldValidation`: `type: string`, `success: boolean`,
  `error_message: string`; validate-multiple results additionally contain
  `field_id: string`.
- `FieldType`: `type: string`, `name: string`.

### Webhook schemas

- `WebhookSubscription`: `events: [string]`, `is_active: boolean`,
  `url?: URL string`, `email?: string`, `updated_at?: date-time`. The SDK also
  tolerates extension/legacy `id` and `created_at` fields.
- `WebhookEventType`: `id: string`, `description: string`.
- `WebhookDispatch`: `resource: string`, `id: string`, `event: string`,
  `activity_id: integer`, `endpoint?: URL string`, `payload?: object`,
  `delivered: boolean`, `http_status?: integer`, `response_body?: string`,
  `error?: string`, `created_at: date-time`, `updated_at: date-time`.

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

`HTTPClientProtocol.perform(_:)` is the public low-level transport seam used by
custom clients and tests. It accepts an `APIRequest(method, path, queryItems,
body, contentType)` and returns `APIResponse(data, headers, statusCode)`. It has
no fixed Assinafy path or schema of its own. The built-in transport throws
`APIError` for non-2xx HTTP responses and `NetworkError` for transport failures.

## Objective-C completion wrappers

Completion-handler methods are main-queue mirrors of their async counterparts;
they do not define different HTTP operations or payloads. The SDK exposes these
mirrors for the documented auth, workspace, signer, document, assignment,
template, tag, field, and webhook resource methods. Array-returning wrappers
unwrap the same list `data`; error-only wrappers discard the same response body.
Use the corresponding async row above as the authoritative request and response
contract.

## Live-test safety gates

The default test suite uses mocked transport and requires no credentials. Live
tests are opt-in:

```sh
ASSINAFY_API_KEY="{sandbox-api-key}" \
ASSINAFY_ACCOUNT_ID="account_example_001" \
ASSINAFY_BASE_URL="https://sandbox.assinafy.com.br/v1" \
swift test --filter AssinafyLiveTests
```

Mutation tests remain skipped unless all of the following are also set:

```sh
ASSINAFY_RUN_LIVE_MUTATIONS=1 \
ASSINAFY_TEST_EMAIL_A="recipient-a@example.test" \
ASSINAFY_TEST_EMAIL_B="recipient-b@example.test"
```

Use two distinct controlled recipients. Never commit credentials, account IDs,
signer access codes, personal addresses, or captured API payloads.
