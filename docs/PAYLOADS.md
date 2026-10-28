# Request and response payloads

Use this catalog with the [SDK method reference](API_REFERENCE.md), which names
arguments, credentials, query parameters, validation and host-specific behavior.
The [Assinafy API](https://api.assinafy.com.br/v1/docs) defines the wire contract.
Examples are synthetic; identifiers, addresses, passwords and URLs are not usable
credentials or recipients. Dates are illustrative. Optional request keys can be
omitted; response keys can be absent or null where the model reference permits it.

Every JSON request below includes all of its named fields. Required fields and
conditional rules are in the method reference. Arrays illustrate one item, not a
limit. Untyped JSON objects are represented as `{}` because their members belong
to the caller. No body means no JSON body, rather than an empty object.

Responses use `{"status":200,"message":"Success","data":...}` unless explicitly
marked flat. The response catalog shows the complete `data` object; list routes
wrap it in an array. Pagination is in HTTP headers, not the JSON body. Void SDK
methods validate status and discard any returned data.

## Operations

| HTTP operation | Request | Response data |
| --- | --- | --- |
| `GET /v1/accounts/{accountId}` | No body | [Account](#account) |
| `PUT /v1/accounts/{accountId}` | [JSON](#request-1) | [Account](#account) |
| `DELETE /v1/accounts/{accountId}` | [JSON](#request-2) | [JSON](#response-1) |
| `GET /v1/accounts/{accountId}/theme` | No body | [AccountTheme](#accounttheme) |
| `GET /v1/accounts/{accountId}/logo` | No body | image/* bytes |
| `POST /v1/accounts/{accountId}/logo` | Multipart: `file` | Envelope without data |
| `DELETE /v1/accounts/{accountId}/logo` | No body | Envelope without data |
| `GET /v1/accounts` | No body | Array of [Account](#account) |
| `POST /v1/accounts` | [JSON](#request-3) | [Account](#account) |
| `GET /v1/documents/{documentId}/activities` | No body | Array of [DocumentActivity](#documentactivity) |
| `GET /v1/assignments` | No body | Array of [Assignment](#assignment) |
| `POST /v1/documents/{documentId}/assignments` | [JSON](#request-4) | [Assignment](#assignment) |
| `POST /v1/documents/{documentId}/assignments/estimate-cost` | [JSON](#request-5) | [CostEstimate](#costestimate) |
| `PUT /v1/documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/resend` | No body | [JSON](#response-2) |
| `POST /v1/documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/estimate-resend-cost` | No body | [ResendCostEstimate](#resendcostestimate) |
| `PUT /v1/documents/{documentId}/assignments/{assignmentId}/reset-expiration` | [JSON](#request-6) | [Assignment](#assignment) |
| `POST /v1/login` | [JSON](#request-7) | [AuthSession](#authsession) |
| `PUT /v1/authentication/request-password-reset` | [JSON](#request-8) | [JSON](#response-3) |
| `PUT /v1/authentication/reset-password` | [JSON](#request-9) | [JSON](#response-4) |
| `PUT /v1/authentication/change-password` | [JSON](#request-10) | [JSON](#response-5) |
| `GET /v1/accounts/{accountId}/documents` | No body | Array of [Document](#document) |
| `POST /v1/accounts/{accountId}/documents` | Multipart: `file` | [Document](#document) |
| `GET /v1/accounts/{accountId}/documents/search` | No body | Array of [Document](#document) |
| `GET /v1/documents/statuses` | No body | Array of [DocumentStatus](#documentstatus) |
| `GET /v1/documents/{documentId}` | No body | [Document](#document) |
| `DELETE /v1/documents/{documentId}` | No body | [JSON](#response-6) |
| `PATCH /v1/documents/{documentId}` | [JSON](#request-11) | [Document](#document) |
| `GET /v1/documents/{documentId}/download/{artifactName}` | No body | application/pdf bytes |
| `GET /v1/documents/{documentSignatureHash}/verify` | No body | [DocumentVerification](#documentverification) |
| `GET /v1/accounts/{accountId}/documents/{documentId}/tags` | No body | Array of [Tag](#tag) |
| `PUT /v1/accounts/{accountId}/documents/{documentId}/tags` | [JSON](#request-12) | Array of [Tag](#tag) |
| `POST /v1/accounts/{accountId}/documents/{documentId}/tags` | [JSON](#request-13) | Array of [Tag](#tag) |
| `DELETE /v1/accounts/{accountId}/documents/{documentId}/tags/{tagId}` | No body | [JSON](#response-7) |
| `GET /v1/accounts/{accountId}/fields` | No body | Array of [Field](#field) |
| `POST /v1/accounts/{accountId}/fields` | [JSON](#request-14) | [Field](#field) |
| `GET /v1/accounts/{accountId}/fields/{fieldId}` | No body | [Field](#field) |
| `PUT /v1/accounts/{accountId}/fields/{fieldId}` | [JSON](#request-15) | [Field](#field) |
| `DELETE /v1/accounts/{accountId}/fields/{fieldId}` | No body | [JSON](#response-8) |
| `POST /v1/accounts/{accountId}/fields/{fieldId}/validate` | [JSON](#request-16) | [FieldValidation](#fieldvalidation) |
| `POST /v1/accounts/{accountId}/fields/validate-multiple` | [JSON](#request-17) | Array of [FieldValidationResult](#fieldvalidationresult) |
| `GET /v1/field-types` | No body | Array of [FieldType](#fieldtype) |
| `GET /v1/users/self/notification-preferences` | No body | [NotificationPreferences](#notificationpreferences) |
| `PUT /v1/users/self/notification-preferences` | [JSON](#request-18) | [NotificationPreferences](#notificationpreferences) |
| `POST /v1/oauth/token` | [Form fields](#request-19) | Flat [JSON](#response-9) |
| `POST /v1/oauth/revoke` | [Form fields](#request-20) | Empty body |
| `GET /v1/oauth/userinfo` | No body | Flat [JSON](#response-10) |
| `GET /v1/documents/{documentId}/thumbnail` | No body | image/* bytes |
| `GET /v1/documents/{documentId}/pages/{pageId}/download` | No body | image/* bytes |
| `GET /v1/public/documents/{documentId}` | No body | [Document](#document) |
| `PUT /v1/public/documents/{documentId}/send-token` | [JSON](#request-21) | [SendToken](#sendtoken) |
| `GET /v1/accounts/{accountId}/signers` | No body | Array of [Signer](#signer) |
| `POST /v1/accounts/{accountId}/signers` | [JSON](#request-22) | [Signer](#signer) |
| `GET /v1/accounts/{accountId}/signers/{signerId}` | No body | [Signer](#signer) |
| `PUT /v1/accounts/{accountId}/signers/{signerId}` | [JSON](#request-23) | [Signer](#signer) |
| `DELETE /v1/accounts/{accountId}/signers/{signerId}` | No body | [JSON](#response-11) |
| `GET /v1/signers/self` | No body | [SignerSelf](#signerself) |
| `GET /v1/signers/{signerId}/document` | No body | [Document](#document) |
| `GET /v1/sign` | No body | [Document](#document) |
| `POST /v1/documents/{documentId}/assignments/{assignmentId}` | [JSON](#request-24) | [JSON](#response-12) |
| `PUT /v1/documents/{documentId}/assignments/{assignmentId}/reject` | [JSON](#request-25) | [JSON](#response-13) |
| `PUT /v1/signers/documents/sign-multiple` | [JSON](#request-26) | [JSON](#response-14) |
| `PUT /v1/signers/documents/decline-multiple` | [JSON](#request-27) | [JSON](#response-15) |
| `POST /v1/verify` | [JSON](#request-28) | Envelope without data |
| `PUT /v1/documents/{documentId}/signers/confirm-data` | [JSON](#request-29) | [Signer](#signer) |
| `PUT /v1/signers/accept-terms` | No body | Envelope without data |
| `POST /v1/signature` | image/png bytes | Envelope without data |
| `GET /v1/signature/{signatureType}` | No body | image/* bytes |
| `GET /v1/signers/{signerId}/documents` | No body | Array of [Document](#document) |
| `GET /v1/signers/{signerId}/documents/search` | No body | Array of [Document](#document) |
| `GET /v1/signers/{signerId}/documents/{documentId}/download/{artifactName}` | No body | application/pdf bytes |
| `POST /v1/authentication/social-login` | [JSON](#request-30) | [AuthSession](#authsession) |
| `POST /v1/auth/link-social-login` | [JSON](#request-31) | Envelope without data |
| `GET /v1/accounts/{accountId}/stats` | No body | Array of [DocumentStatsRow](#documentstatsrow) |
| `GET /v1/users/self/stats` | No body | Array of [DocumentStatsRow](#documentstatsrow) |
| `GET /v1/accounts/{accountId}/tags` | No body | Array of [Tag](#tag) |
| `POST /v1/accounts/{accountId}/tags` | [JSON](#request-32) | [Tag](#tag) |
| `PUT /v1/accounts/{accountId}/tags/{tagId}` | [JSON](#request-33) | [Tag](#tag) |
| `DELETE /v1/accounts/{accountId}/tags/{tagId}` | No body | [JSON](#response-16) |
| `GET /v1/accounts/{accountId}/templates` | No body | Array of [Template](#template) |
| `POST /v1/accounts/{accountId}/templates/{templateId}/documents` | [JSON](#request-34) | [Document](#document) |
| `POST /v1/accounts/{accountId}/templates/{templateId}/documents/estimate-cost` | [JSON](#request-35) | [CostEstimate](#costestimate) |
| `GET /v1/users/self` | No body | [AuthUser](#authuser) |
| `GET /v1/users/api-keys` | No body | [ApiKey](#apikey) |
| `POST /v1/users/api-keys` | [JSON](#request-36) | [ApiKey](#apikey) |
| `DELETE /v1/users/api-keys` | No body | [JSON](#response-17) |
| `GET /v1/accounts/{accountId}/webhooks/subscriptions` | No body | [WebhookSubscription](#webhooksubscription) |
| `PUT /v1/accounts/{accountId}/webhooks/subscriptions` | [JSON](#request-37) | [WebhookSubscription](#webhooksubscription) |
| `PUT /v1/accounts/{accountId}/webhooks/inactivate` | No body | [WebhookSubscription](#webhooksubscription) |
| `GET /v1/webhooks/event-types` | No body | Array of [WebhookEventType](#webhookeventtype) |
| `GET /v1/accounts/{accountId}/webhooks` | No body | Array of [WebhookDispatch](#webhookdispatch) |
| `POST /v1/accounts/{accountId}/webhooks/{historyId}/retry` | No body | [WebhookDispatch](#webhookdispatch) |
| `GET /v1/accounts/{accountId}/webhooks/endpoints` | No body | Array of [WebhookEndpoint](#webhookendpoint) |
| `POST /v1/accounts/{accountId}/webhooks/endpoints` | [JSON](#request-38) | [WebhookEndpoint](#webhookendpoint) |
| `GET /v1/accounts/{accountId}/webhooks/endpoints/{endpointId}` | No body | [WebhookEndpoint](#webhookendpoint) |
| `PUT /v1/accounts/{accountId}/webhooks/endpoints/{endpointId}` | [JSON](#request-39) | [WebhookEndpoint](#webhookendpoint) |
| `DELETE /v1/accounts/{accountId}/webhooks/endpoints/{endpointId}` | No body | [JSON](#response-1) |
| `GET /v1/accounts/{accountId}/webhooks/endpoints/{endpointId}/secret` | No body | [WebhookSigningSecret](#webhooksigningsecret) |
| `POST /v1/accounts/{accountId}/webhooks/endpoints/{endpointId}/secret/rotate` | No body | [WebhookSigningSecret](#webhooksigningsecret) |
| `POST /v1/authentication/mfa/verify` | [JSON](#request-40) | [AuthSession](#authsession) |
| `GET /v1/users/self/mfa` | No body | [MFAStatus](#mfastatus) |
| `POST /v1/users/self/mfa/totp` | [JSON](#request-41) | [TOTPEnrollment](#totpenrollment) |
| `PUT /v1/users/self/mfa/totp/confirm` | [JSON](#request-42) | [RecoveryCodes](#recoverycodes) |
| `POST /v1/users/self/mfa/recovery-codes` | [JSON](#request-43) | [RecoveryCodes](#recoverycodes) |
| `DELETE /v1/users/self/mfa/{customId}` | [JSON](#request-43) | [JSON](#response-19) |
| `GET /.well-known/oauth-protected-resource` | No body | Flat [JSON](#response-18) |
| `GET /v1/documents/{documentId}/assignments/{assignmentId}/whatsapp-notifications` | No body | Array of [WhatsappNotification](#whatsappnotification) |
| `GET /v1/signers/identity-verification` | No body; signer access code query | [IdentityVerificationState](#identityverificationstate) |
| `POST /v1/signers/identity-verification` | [Consent JSON](#startidentityverificationpayload); signer access code query | [IdentityVerificationSession](#identityverificationsession) |
| `GET /v1/documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/identity-verification` | No body | [SignerIdentityReview](#signeridentityreview) |
| `GET /v1/documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/identity-verification/images/{name}` | No body | JPEG, PNG or PDF bytes |
| `POST /v1/documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/identity-verification/review` | [Decision JSON](#reviewidentityverificationpayload) | [SignerIdentityReview](#signeridentityreview) |
| `DELETE /v1/accounts/{accountId}/webhooks/endpoints` | No body; exact `url` query | Envelope with `data: []` |

OAuth token, revocation, authorization-server discovery and userinfo payloads are
[documented separately](API_REFERENCE.md#oauth-21), including their flat responses
and form encoding. Template create/get/update/delete use
[the template SDK methods](API_REFERENCE.md#templates): creation is multipart
`name` and `file`; updates encode `name`, `document_name`, and `message`;
get/create/update return the `Template` data object; deletion returns an envelope.



Query parameters carry the signer access code only on signer-scoped routes; account
credentials are withheld there. Signature upload also takes `type=signature|initial`
and optional `reuse=true|false`: omit reuse to preserve the previous preference.
Assignment listing takes camelCase `accountId` from the argument or client default
on every host; API-key/session callers supply it, while OAuth may derive the account.
Activity listing accepts `page`, `per-page`, and `sort=id|-id`; document search accepts
`page`, `per-page`, and `sort=name|updated_at` with `-` for descending.
Literal `+` query values are encoded as `%2B`.

## Request bodies

### request-1

`PUT /v1/accounts/{accountId}`

```json
{
  "name": "example",
  "notification_sender_type": "User"
}
```

### request-2

`DELETE /v1/accounts/{accountId}`

```json
{
  "force": true
}
```

### request-3

`POST /v1/accounts`

```json
{
  "name": "example",
  "notification_sender_type": "User"
}
```

### request-4

`POST /v1/documents/{documentId}/assignments`

```json
{
  "method": "virtual",
  "signers": [
    {
      "id": "id_example_001",
      "verification_method": "Email",
      "notification_methods": [
        "Email"
      ],
      "step": 1
    }
  ],
  "entries": [
    {
      "page_id": "page_id_example_001",
      "fields": [
        {
          "signer_id": "signer_id_example_001",
          "field_id": "field_id_example_001",
          "display_settings": {
            "left": 1,
            "top": 1,
            "width": 1,
            "height": 1,
            "fontFamily": "example",
            "fontSize": 1,
            "backgroundColor": "example"
          }
        }
      ]
    }
  ],
  "message": "Success",
  "expires_at": "2099-01-01T12:00:00Z",
  "copy_receivers": [
    "example"
  ]
}
```

### request-5

`POST /v1/documents/{documentId}/assignments/estimate-cost`

```json
{
  "method": "virtual",
  "signers": [
    {
      "verification_method": "Email",
      "notification_methods": [
        "Email"
      ]
    }
  ]
}
```

### request-6

`PUT /v1/documents/{documentId}/assignments/{assignmentId}/reset-expiration`

```json
{
  "expires_at": "2099-01-01T12:00:00Z"
}
```

### request-7

`POST /v1/login`

```json
{
  "email": "signer@example.invalid",
  "password": "synthetic-password"
}
```

### request-8

`PUT /v1/authentication/request-password-reset`

```json
{
  "email": "signer@example.invalid"
}
```

### request-9

`PUT /v1/authentication/reset-password`

```json
{
  "email": "signer@example.invalid",
  "token": "example",
  "new_password": "synthetic-password"
}
```

### request-10

`PUT /v1/authentication/change-password`

```json
{
  "email": "signer@example.invalid",
  "password": "synthetic-password",
  "new_password": "synthetic-password"
}
```

### request-11

`PATCH /v1/documents/{documentId}`

```json
{
  "name": "example"
}
```

### request-12

`PUT /v1/accounts/{accountId}/documents/{documentId}/tags`

```json
{
  "tags": [
    "example"
  ]
}
```

### request-13

`POST /v1/accounts/{accountId}/documents/{documentId}/tags`

```json
{
  "tags": [
    "example"
  ]
}
```

### request-14

`POST /v1/accounts/{accountId}/fields`

```json
{
  "name": "example",
  "type": "example",
  "regex": "^[A-Z]+$",
  "is_required": true
}
```

### request-15

`PUT /v1/accounts/{accountId}/fields/{fieldId}`

```json
{
  "name": "example",
  "regex": "^[A-Z]+$",
  "is_active": true
}
```

### request-16

`POST /v1/accounts/{accountId}/fields/{fieldId}/validate`

```json
{
  "value": null
}
```

### request-17

`POST /v1/accounts/{accountId}/fields/validate-multiple`

```json
[
  {
    "field_id": "field_id_example_001",
    "value": null
  }
]
```

### request-18

`PUT /v1/users/self/notification-preferences`

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
  "SignerWhatsappFailed": true,
  "ContractRenewalNotice": true,
  "ContractExpiring": true,
  "ContractExpired": true,
  "ContractRenewed": true
}
```

### request-19

`POST /v1/oauth/token`

The object below lists form fields; the wire content type is
`application/x-www-form-urlencoded`, not JSON. Mobile clients omit `client_secret`.

```json
{
  "grant_type": "authorization_code",
  "code": "ac_example_001",
  "redirect_uri": "https://app.example.invalid/oauth/callback",
  "code_verifier": "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk",
  "client_id": "client_id_example_001",
  "resource": "https://api.assinafy.com.br"
}
```

### request-20

`POST /v1/oauth/revoke`

Encode these fields as `application/x-www-form-urlencoded`.

```json
{
  "token": "rt_example_001",
  "token_type_hint": "refresh_token",
  "client_id": "client_id_example_001"
}
```

### request-21

`PUT /v1/public/documents/{documentId}/send-token`

```json
{
  "channel": "email",
  "recipient": "signer@example.com"
}
```

### request-22

`POST /v1/accounts/{accountId}/signers`

```json
{
  "full_name": "example",
  "email": "signer@example.invalid",
  "whatsapp_phone_number": null,
  "government_id": "00000000000"
}
```

### request-23

`PUT /v1/accounts/{accountId}/signers/{signerId}`

```json
{
  "full_name": "example",
  "email": "signer@example.invalid",
  "whatsapp_phone_number": null,
  "government_id": null
}
```

### request-24

`POST /v1/documents/{documentId}/assignments/{assignmentId}`

```json
[
  {
    "itemId": "itemId_example_001",
    "fieldId": "fieldId_example_001",
    "pageId": "pageId_example_001",
    "value": "example"
  }
]
```

### request-25

`PUT /v1/documents/{documentId}/assignments/{assignmentId}/reject`

```json
{
  "decline_reason": "example"
}
```

### request-26

`PUT /v1/signers/documents/sign-multiple`

```json
{
  "document_ids": [
    "example"
  ]
}
```

### request-27

`PUT /v1/signers/documents/decline-multiple`

```json
{
  "document_ids": [
    "example"
  ],
  "decline_reason": "example"
}
```

### request-28

`POST /v1/verify`

```json
{
  "verification-code": "123456"
}
```

### request-29

`PUT /v1/documents/{documentId}/signers/confirm-data`

```json
{
  "full_name": "example",
  "email": "signer@example.invalid",
  "government_id": null
}
```

### request-30

`POST /v1/authentication/social-login`

```json
{
  "provider": "google",
  "token": "example",
  "has_accepted_terms": true
}
```

### request-31

`POST /v1/auth/link-social-login`

```json
{
  "provider": "google",
  "token": "example"
}
```

### request-32

`POST /v1/accounts/{accountId}/tags`

```json
{
  "name": "example",
  "color": "2072b9"
}
```

### request-33

`PUT /v1/accounts/{accountId}/tags/{tagId}`

```json
{
  "name": "example",
  "color": "2072b9"
}
```

### request-34

`POST /v1/accounts/{accountId}/templates/{templateId}/documents`

```json
{
  "signers": [
    {
      "role_id": "role_id_example_001",
      "id": "id_example_001",
      "verification_method": "Email",
      "notification_methods": [
        "Email"
      ],
      "step": 1
    },
    {
      "role_id": "role_id_example_002",
      "email": "new-signer@example.invalid",
      "name": "Example Signer",
      "whatsapp_phone_number": "+5511000000000",
      "verification_method": "Email",
      "notification_methods": [
        "Email"
      ],
      "step": 2
    }
  ],
  "editor_fields": [
    {
      "field_id": "field_id_example_001",
      "value": "example"
    }
  ],
  "name": "example",
  "message": "Success",
  "expires_at": "2099-01-01T12:00:00Z",
  "tags": [
    "example"
  ]
}
```

Each signer uses an existing `id` or an `email` for lookup/creation. `name` and
`whatsapp_phone_number` apply only when creating a signer. The response initially
has `status: "uploaded"` and may have `assignment: null`; wait for processing before
reading signing links. Cost estimation omits ID, email, name, phone and step.

### request-35

`POST /v1/accounts/{accountId}/templates/{templateId}/documents/estimate-cost`

```json
{
  "signers": [
    {
      "role_id": "role_id_example_001",
      "verification_method": "Email",
      "notification_methods": [
        "Email"
      ]
    }
  ]
}
```

### request-36

`POST /v1/users/api-keys`

```json
{
  "password": "synthetic-password"
}
```

### request-37

`PUT /v1/accounts/{accountId}/webhooks/subscriptions`

```json
{
  "events": [
    "document_ready"
  ],
  "is_active": true,
  "url": "https://app.example.invalid/resource",
  "email": "signer@example.invalid"
}
```

### request-38

`POST /v1/accounts/{accountId}/webhooks/endpoints`

```json
{
  "url": "https://app.example.invalid/webhooks/assinafy",
  "email": "ops@example.invalid",
  "events": [
    "document_ready",
    "signer_signed_document"
  ],
  "name": "ERP",
  "is_active": true,
  "signing_enabled": true
}
```

### request-39

`PUT /v1/accounts/{accountId}/webhooks/endpoints/{endpointId}`

```json
{
  "url": "https://app.example.invalid/webhooks/assinafy",
  "email": "ops@example.invalid",
  "events": [
    "document_ready"
  ],
  "name": "ERP",
  "is_active": false,
  "signing_enabled": true
}
```

### request-40

`POST /v1/authentication/mfa/verify`

```json
{
  "mfa_token": "mfa_token_example_001",
  "code": "123456"
}
```

### request-41

`POST /v1/users/self/mfa/totp`

```json
{
  "label": "My phone"
}
```

### request-42

`PUT /v1/users/self/mfa/totp/confirm`

```json
{
  "id": "mfa_method_id_example_001",
  "code": "123456",
  "password": "synthetic-password",
  "reauth_code": "654321"
}
```

`password` and `reauth_code` are needed only when replacing a confirmed method.

### request-43

`POST /v1/users/self/mfa/recovery-codes` and `DELETE /v1/users/self/mfa/{customId}`

```json
{
  "password": "synthetic-password",
  "code": "123456"
}
```

Send the password, a live authenticator code, or a recovery code; one is enough.

## Response bodies

### response-1

`DELETE /v1/accounts/{accountId}`

```json
[]
```

### response-2

`PUT /v1/documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/resend`

```json
{
  "is_sent": true,
  "document_id": "document_id_example_001",
  "signer_id": "signer_id_example_001"
}
```

### response-3

`PUT /v1/authentication/request-password-reset`

```json
{
  "email": "signer@example.invalid"
}
```

### response-4

`PUT /v1/authentication/reset-password`

```json
{
  "email": "signer@example.invalid"
}
```

### response-5

`PUT /v1/authentication/change-password`

```json
{
  "email": "signer@example.invalid"
}
```

### response-6

`DELETE /v1/documents/{documentId}`

```json
[]
```

### response-7

`DELETE /v1/accounts/{accountId}/documents/{documentId}/tags/{tagId}`

```json
{
  "detached": true
}
```

### response-8

`DELETE /v1/accounts/{accountId}/fields/{fieldId}`

```json
[]
```

### response-9

`POST /v1/oauth/token`

```json
{
  "access_token": "at_example_001",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "rt_example_001",
  "scope": "documents:read documents:write",
  "id_token": "synthetic.id.token"
}
```

### response-10

`GET /v1/oauth/userinfo`

```json
{
  "sub": "example",
  "name": "example",
  "email": "signer@example.invalid",
  "email_verified": true
}
```

### response-11

`DELETE /v1/accounts/{accountId}/signers/{signerId}`

```json
[]
```

### response-12

`POST /v1/documents/{documentId}/assignments/{assignmentId}`

```json
{}
```

### response-13

`PUT /v1/documents/{documentId}/assignments/{assignmentId}/reject`

```json
[]
```

### response-14

`PUT /v1/signers/documents/sign-multiple`

```json
[]
```

### response-15

`PUT /v1/signers/documents/decline-multiple`

```json
[]
```

### response-16

`DELETE /v1/accounts/{accountId}/tags/{tagId}`

```json
{
  "deleted": true
}
```

### response-17

`DELETE /v1/users/api-keys`

```json
[]
```

### response-18

`GET /.well-known/oauth-protected-resource`

```json
{
  "resource": "https://api.assinafy.com.br",
  "authorization_servers": [
    "https://auth.assinafy.com.br"
  ],
  "scopes_supported": [
    "documents:read", "documents:write", "templates:read", "templates:write",
    "account:read", "webhooks:write", "openid", "profile", "email"
  ],
  "bearer_methods_supported": [
    "header"
  ]
}
```

### response-19

`DELETE /v1/users/self/mfa/{customId}`

```json
{
  "is_mfa_enabled": false
}
```

### MFAChallenge

```json
{
  "mfa_token": "mfa_token_example_001"
}
```

`POST /v1/login` and `POST /v1/authentication/social-login` answer this for a user
with two-factor authentication. The SDK throws `MFARequiredError` with the token.

## Response catalog

### Envelope

```json
{
  "status": 200,
  "message": "Success"
}
```

### ErrorEnvelope

```json
{
  "status": 422,
  "message": "Validation failed",
  "data": {}
}
```

### ApiKey

```json
{
  "api_key": "example"
}
```

### AuthUser

```json
{
  "id": "id_example_001",
  "name": "example",
  "email": "signer@example.invalid",
  "telephone": null,
  "government_id": null,
  "is_email_verified": true,
  "has_accepted_terms": true,
  "created_at": "2099-01-01T12:00:00Z",
  "to_be_deleted_at": "2099-01-01T12:00:00Z"
}
```

### AuthAccount

```json
{
  "id": "id_example_001",
  "name": "example",
  "roles": [
    "example"
  ],
  "is_delete_allowed": true,
  "created_at": "2099-01-01T12:00:00Z"
}
```

### Signer

```json
{
  "resource": "signer",
  "id": "id_example_001",
  "full_name": "example",
  "email": "signer@example.invalid",
  "whatsapp_phone_number": null,
  "government_id": null,
  "has_accepted_terms": true
}
```

### SignerSelf

```json
{
  "resource": "signer",
  "id": "id_example_001",
  "full_name": "example",
  "email": "signer@example.invalid",
  "whatsapp_phone_number": null,
  "has_accepted_terms": true,
  "has_signature": true,
  "has_initial": true,
  "is_signature_reusable": true
}
```

### DocumentPage

```json
{
  "id": "id_example_001",
  "number": 1,
  "height": 1,
  "width": 1,
  "download_url": "https://app.example.invalid/resource"
}
```

### DisplaySettings

```json
{
  "left": 1,
  "top": 1,
  "width": 1,
  "height": 1,
  "fontFamily": "example",
  "fontSize": 1,
  "backgroundColor": "example"
}
```

### DocumentStatus

```json
{
  "code": "example",
  "deletable": true
}
```

### Document

```json
{
  "resource": "document",
  "id": "id_example_001",
  "account_id": "account_id_example_001",
  "template_id": "template_id_example_001",
  "name": "example",
  "status": "uploaded",
  "artifacts": {
    "original": "https://app.example.invalid/documents/document_example_001/original",
    "thumbnail": "https://app.example.invalid/documents/document_example_001/thumbnail",
    "certificated": "https://app.example.invalid/documents/document_example_001/certificated",
    "certificate-page": "https://app.example.invalid/documents/document_example_001/certificate-page",
    "pades": "https://app.example.invalid/documents/document_example_001/pades",
    "bundle": "https://app.example.invalid/documents/document_example_001/bundle"
  },
  "is_closed": true,
  "signing_url": "https://app.example.invalid/resource",
  "decline_reason": "example",
  "declined_by": {
    "resource": "signer",
    "id": "id_example_001",
    "full_name": "example",
    "email": "signer@example.invalid",
    "whatsapp_phone_number": null,
    "has_accepted_terms": true
  },
  "tags": [
    {
      "id": "id_example_001",
      "name": "example"
    }
  ],
  "assignment": {
    "resource": "assignment",
    "id": "id_example_001",
    "sender_email": "signer@example.invalid",
    "method": "virtual",
    "expires_at": "2099-01-01T12:00:00Z",
    "message": "Success",
    "signers": [
      {
        "resource": "signer",
        "id": "id_example_001",
        "full_name": "example",
        "email": "signer@example.invalid",
        "whatsapp_phone_number": null,
        "has_accepted_terms": true,
        "verification_method": "Email",
        "notification_methods": [
          "Email"
        ],
        "step": 1,
        "notified": true,
        "completed": true,
        "notification_history": [
          {
            "event": "example",
            "status": "sent",
            "error_code": "example",
            "error_message": "example",
            "sent_at": "2099-01-01T12:00:00Z",
            "failed_at": "2099-01-01T12:00:00Z"
          }
        ]
      }
    ],
    "copy_receivers": [
      {
        "resource": "signer",
        "id": "id_example_001",
        "full_name": "example",
        "email": "signer@example.invalid",
        "whatsapp_phone_number": null,
        "has_accepted_terms": true
      }
    ],
    "items": [
      {
        "id": "id_example_001",
        "page": {
          "id": "id_example_001",
          "number": 1,
          "height": 1,
          "width": 1,
          "download_url": "https://app.example.invalid/resource"
        },
        "signer": {
          "resource": "signer",
          "id": "id_example_001",
          "full_name": "example",
          "email": "signer@example.invalid",
          "whatsapp_phone_number": null,
          "has_accepted_terms": true
        },
        "field": {
          "resource": "field",
          "id": "id_example_001",
          "name": "example",
          "type": "example",
          "regex": "^[A-Z]+$",
          "is_pre_defined": true,
          "is_active": true,
          "is_required": true,
          "is_standard": true,
          "is_read_only": true,
          "is_visible": true
        },
        "display_settings": null,
        "value": null,
        "completed": true
      }
    ],
    "summary": {
      "signer_count": 1,
      "completed_count": 1,
      "signers": [
        {
          "resource": "signer",
          "id": "id_example_001",
          "full_name": "example",
          "email": "signer@example.invalid",
          "whatsapp_phone_number": null,
          "has_accepted_terms": true
        }
      ]
    },
    "signing_urls": [
      {
        "signer_id": "signer_id_example_001",
        "url": "https://app.example.invalid/resource"
      }
    ],
    "document_id": "id_example_001",
    "created_at": "2099-01-01T12:00:00Z"
  },
  "pages": [
    {
      "id": "id_example_001",
      "number": 1,
      "height": 1,
      "width": 1,
      "download_url": "https://app.example.invalid/resource"
    }
  ],
  "created_at": "2099-01-01T12:00:00Z",
  "updated_at": "2099-01-01T12:00:00Z",
  "verification_code": "verification_example_001",
  "verification_url": "https://app.example.invalid/verify/verification_example_001",
  "has_contract": false,
  "current_signer": {
    "resource": "signer",
    "id": "id_example_001",
    "full_name": "example",
    "email": "signer@example.invalid",
    "whatsapp_phone_number": null,
    "has_accepted_terms": true,
    "verification_method": "Email",
    "notification_methods": [
      "Email"
    ],
    "step": 1,
    "notified": true,
    "completed": true,
    "notification_history": [
      {
        "event": "example",
        "status": "sent",
        "error_code": "example",
        "error_message": "example",
        "sent_at": "2099-01-01T12:00:00Z",
        "failed_at": "2099-01-01T12:00:00Z"
      }
    ]
  }
}
```

`current_signer` is returned by signer-facing document routes. Verification details
and `has_contract` can be absent or null; the SDK preserves that distinction.

### Account

```json
{
  "resource": "account",
  "id": "id_example_001",
  "name": "example",
  "primary_color": "2072b9",
  "secondary_color": "2072b9",
  "notification_sender_type": "User",
  "roles": [
    "example"
  ],
  "is_delete_allowed": true,
  "created_at": "2099-01-01T12:00:00Z",
  "limits": {
    "webhook_endpoints": 3
  }
}
```

### Field

```json
{
  "resource": "field",
  "id": "id_example_001",
  "name": "example",
  "type": "example",
  "regex": "^[A-Z]+$",
  "is_pre_defined": true,
  "is_active": true,
  "is_required": true,
  "is_standard": true,
  "is_read_only": true,
  "is_visible": true
}
```

### Tag

```json
{
  "resource": "tag",
  "id": "id_example_001",
  "name": "example",
  "color": "2072b9",
  "created_at": "2099-01-01T12:00:00Z",
  "updated_at": "2099-01-01T12:00:00Z"
}
```

### SigningUrl

```json
{
  "signer_id": "signer_id_example_001",
  "url": "https://app.example.invalid/resource"
}
```

### AssignmentSigner

```json
{
  "resource": "signer",
  "id": "id_example_001",
  "full_name": "example",
  "email": "signer@example.invalid",
  "whatsapp_phone_number": null,
  "has_accepted_terms": true,
  "verification_method": "Email",
  "notification_methods": [
    "Email"
  ],
  "step": 1,
  "notified": true,
  "completed": true,
  "notification_history": [
    {
      "event": "example",
      "status": "sent",
      "error_code": "example",
      "error_message": "example",
      "sent_at": "2099-01-01T12:00:00Z",
      "failed_at": "2099-01-01T12:00:00Z"
    }
  ]
}
```

### NotificationHistoryEntry

```json
{
  "event": "example",
  "status": "sent",
  "error_code": "example",
  "error_message": "example",
  "sent_at": "2099-01-01T12:00:00Z",
  "failed_at": "2099-01-01T12:00:00Z"
}
```

### AssignmentItem

```json
{
  "id": "id_example_001",
  "page": {
    "id": "id_example_001",
    "number": 1,
    "height": 1,
    "width": 1,
    "download_url": "https://app.example.invalid/resource"
  },
  "signer": {
    "resource": "signer",
    "id": "id_example_001",
    "full_name": "example",
    "email": "signer@example.invalid",
    "whatsapp_phone_number": null,
    "has_accepted_terms": true
  },
  "field": {
    "resource": "field",
    "id": "id_example_001",
    "name": "example",
    "type": "example",
    "regex": "^[A-Z]+$",
    "is_pre_defined": true,
    "is_active": true,
    "is_required": true,
    "is_standard": true,
    "is_read_only": true,
    "is_visible": true
  },
  "display_settings": null,
  "value": null,
  "completed": true
}
```

### AssignmentSummary

```json
{
  "signer_count": 1,
  "completed_count": 1,
  "signers": [
    {
      "resource": "signer",
      "id": "id_example_001",
      "full_name": "example",
      "email": "signer@example.invalid",
      "whatsapp_phone_number": null,
      "has_accepted_terms": true
    }
  ]
}
```

### Assignment

```json
{
  "resource": "assignment",
  "id": "id_example_001",
  "sender_email": "signer@example.invalid",
  "method": "virtual",
  "expires_at": "2099-01-01T12:00:00Z",
  "message": "Success",
  "signers": [
    {
      "resource": "signer",
      "id": "id_example_001",
      "full_name": "example",
      "email": "signer@example.invalid",
      "whatsapp_phone_number": null,
      "has_accepted_terms": true,
      "verification_method": "Email",
      "notification_methods": [
        "Email"
      ],
      "step": 1,
      "notified": true,
      "completed": true,
      "notification_history": [
        {
          "event": "example",
          "status": "sent",
          "error_code": "example",
          "error_message": "example",
          "sent_at": "2099-01-01T12:00:00Z",
          "failed_at": "2099-01-01T12:00:00Z"
        }
      ]
    }
  ],
  "copy_receivers": [
    {
      "resource": "signer",
      "id": "id_example_001",
      "full_name": "example",
      "email": "signer@example.invalid",
      "whatsapp_phone_number": null,
      "has_accepted_terms": true
    }
  ],
  "items": [
    {
      "id": "id_example_001",
      "page": {
        "id": "id_example_001",
        "number": 1,
        "height": 1,
        "width": 1,
        "download_url": "https://app.example.invalid/resource"
      },
      "signer": {
        "resource": "signer",
        "id": "id_example_001",
        "full_name": "example",
        "email": "signer@example.invalid",
        "whatsapp_phone_number": null,
        "has_accepted_terms": true
      },
      "field": {
        "resource": "field",
        "id": "id_example_001",
        "name": "example",
        "type": "example",
        "regex": "^[A-Z]+$",
        "is_pre_defined": true,
        "is_active": true,
        "is_required": true,
        "is_standard": true,
        "is_read_only": true,
        "is_visible": true
      },
      "display_settings": null,
      "value": null,
      "completed": true
    }
  ],
  "summary": {
    "signer_count": 1,
    "completed_count": 1,
    "signers": [
      {
        "resource": "signer",
        "id": "id_example_001",
        "full_name": "example",
        "email": "signer@example.invalid",
        "whatsapp_phone_number": null,
        "has_accepted_terms": true
      }
    ]
  },
  "signing_urls": [
    {
      "signer_id": "signer_id_example_001",
      "url": "https://app.example.invalid/resource"
    }
  ],
  "document_id": "document_example_001",
  "created_at": "2099-01-01T12:00:00Z"
}
```

### CostEstimateBreakdownItem

```json
{
  "code": "example",
  "name": "example",
  "cost": 1,
  "quantity": 1,
  "unit_cost": 1
}
```

### CostEstimate

```json
{
  "documents": 1,
  "credits": 0.45,
  "needs_extra_document": true,
  "extra_document_cost": 1,
  "total_credits": 1.45,
  "breakdown": [
    {
      "code": "NotificationWhatsapp",
      "name": "WhatsApp notification",
      "cost": 0.45,
      "quantity": 1,
      "unit_cost": 0.45
    }
  ],
  "document_balance": 0,
  "credit_balance": 10,
  "has_sufficient_resources": true,
  "blocking_reason": null,
  "message": "Success"
}
```

### ResendCostEstimate

Reminder costs use a separate wire shape decoded by `CostEstimate`. `totalCredits`
reads `total`, and both sufficiency properties read `has_sufficient_credits`.
A null `credit_balance` means unlimited credits; it remains null in `raw` while
the numeric compatibility property is zero. A reminder consumes no document.

```json
{
  "total": 0.45,
  "breakdown": [
    {
      "code": "NotificationWhatsappResend",
      "name": "WhatsApp reminder",
      "cost": 0.45
    }
  ],
  "credit_balance": null,
  "has_sufficient_credits": true
}
```

### TemplateFieldPlacement

```json
{
  "id": "id_example_001",
  "field_id": "field_id_example_001",
  "role_id": "role_id_example_001",
  "label": "example",
  "display_settings": null,
  "created_at": "2099-01-01T12:00:00Z",
  "updated_at": "2099-01-01T12:00:00Z"
}
```

### TemplatePage

```json
{
  "id": "id_example_001",
  "number": 1,
  "height": 1,
  "width": 1,
  "download_url": "https://app.example.invalid/resource",
  "fields": [
    {
      "id": "id_example_001",
      "field_id": "field_id_example_001",
      "role_id": "role_id_example_001",
      "label": "example",
      "display_settings": null,
      "created_at": "2099-01-01T12:00:00Z",
      "updated_at": "2099-01-01T12:00:00Z"
    }
  ]
}
```

### TemplateRole

```json
{
  "id": "id_example_001",
  "name": "example",
  "assignment_type": "example",
  "created_at": "2099-01-01T12:00:00Z",
  "updated_at": "2099-01-01T12:00:00Z"
}
```

### Template

```json
{
  "resource": "template",
  "id": "id_example_001",
  "name": "example",
  "document_name": "example",
  "message": "Success",
  "status": "uploaded",
  "pages": [
    {
      "id": "id_example_001",
      "number": 1,
      "height": 1,
      "width": 1,
      "download_url": "https://app.example.invalid/resource",
      "fields": [
        {
          "id": "id_example_001",
          "field_id": "field_id_example_001",
          "role_id": "role_id_example_001",
          "label": "example",
          "display_settings": null,
          "created_at": "2099-01-01T12:00:00Z",
          "updated_at": "2099-01-01T12:00:00Z"
        }
      ]
    }
  ],
  "roles": [
    {
      "id": "id_example_001",
      "name": "example",
      "assignment_type": "example",
      "created_at": "2099-01-01T12:00:00Z",
      "updated_at": "2099-01-01T12:00:00Z"
    }
  ],
  "tags": [
    {
      "id": "id_example_001",
      "name": "example"
    }
  ],
  "default_document_tags": [
    {
      "id": "id_example_001",
      "name": "example"
    }
  ],
  "created_at": "2099-01-01T12:00:00Z",
  "updated_at": "2099-01-01T12:00:00Z"
}
```

### WebhookSubscription

```json
{
  "events": [
    "document_ready"
  ],
  "is_active": true,
  "url": "https://app.example.invalid/resource",
  "email": "signer@example.invalid",
  "updated_at": "2099-01-01T12:00:00Z",
  "is_held": false,
  "held_since": null
}
```

### WebhookDispatch

```json
{
  "resource": "activity_dispatching_history",
  "id": "id_example_001",
  "event": "document_ready",
  "activity_id": 1,
  "endpoint": "https://app.example.invalid/webhooks/assinafy",
  "endpoint_id": "endpoint_id_example_001",
  "payload": {},
  "delivered": true,
  "http_status": 200,
  "response_body": "OK",
  "error": null,
  "created_at": "2099-01-01T12:00:00Z",
  "updated_at": "2099-01-01T12:00:00Z",
  "webhook_id": "delivery_example_001",
  "attempt": 2,
  "kind": "scheduled",
  "will_retry": false
}
```

### WebhookEndpoint

```json
{
  "id": "endpoint_id_example_001",
  "name": "ERP",
  "url": "https://app.example.invalid/webhooks/assinafy",
  "email": "ops@example.invalid",
  "events": [
    "document_ready",
    "signer_signed_document"
  ],
  "is_active": true,
  "signing_enabled": true,
  "created_at": "2099-01-01T12:00:00Z",
  "updated_at": "2099-01-01T12:00:00Z",
  "is_held": false,
  "held_since": null
}
```

### WebhookSigningSecret

```json
{
  "secret": "whsec_c3ludGhldGljLXNpZ25pbmcta2V5"
}
```

### MFAStatus

```json
{
  "methods": [
    {
      "id": "mfa_method_id_example_001",
      "type": "Totp",
      "label": "My phone",
      "confirmed_at": "2099-01-01T12:00:00Z",
      "last_used_at": "2099-01-01T12:00:00Z"
    }
  ],
  "recovery_codes_remaining": 8
}
```

### TOTPEnrollment

```json
{
  "id": "mfa_method_id_example_001",
  "secret": "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
  "provisioning_uri": "otpauth://totp/user%40example.invalid?issuer=Assinafy&secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
}
```

### RecoveryCodes

```json
{
  "recovery_codes": [
    "ABCD-EFGH-JKMN"
  ]
}
```

### WebhookEventType

```json
{
  "id": "id_example_001",
  "description": "example"
}
```

### AccountTheme

```json
{
  "account_name": "example",
  "primary_color": "2072b9",
  "secondary_color": "2072b9",
  "logo": "https://app.example.invalid/resource"
}
```

### FieldType

```json
{
  "type": "example",
  "name": "example"
}
```

### FieldValidation

```json
{
  "type": "example",
  "success": true,
  "error_message": "example"
}
```

### FieldValidationResult

```json
{
  "field_id": "field_id_example_001",
  "type": "example",
  "success": true,
  "error_message": "example"
}
```

### SendToken

```json
{
  "document": {
    "resource": "document",
    "id": "document_id_example_001",
    "name": "contract.pdf",
    "page_count": 1,
    "created_by": "Example Workspace"
  },
  "channel": "email",
  "recipient": "signer@example.com"
}
```

### DocumentVerification

```json
{
  "hash": "example",
  "id": "id_example_001",
  "agreement_code": "example",
  "status": "certificated",
  "page_count": "1",
  "signer_count": "1",
  "completed_count": 1,
  "completed_at": "2099-01-01T12:00:00Z",
  "verified_at": "2099-01-01T12:00:00Z",
  "is_valid": true,
  "message": "Success"
}
```

### DocumentActivity

```json
{
  "id": 1,
  "event": "example",
  "message": "Success",
  "payload": {},
  "origin": {
    "ip": "example",
    "user-agent": "example"
  },
  "created_at": "2099-01-01T12:00:00Z"
}
```

### WhatsappNotification

```json
{
  "sent_at": "2099-01-01T12:00:00Z",
  "header": "example",
  "body": "example",
  "buttons": [
    {
      "text": "example"
    }
  ],
  "phone_number": "example",
  "signer_id": "signer_id_example_001"
}
```

### AuthSession

```json
{
  "access_token": "example",
  "user": {
    "id": "id_example_001",
    "name": "example",
    "email": "signer@example.invalid",
    "telephone": null,
    "government_id": null,
    "is_email_verified": true,
    "has_accepted_terms": true,
    "created_at": "2099-01-01T12:00:00Z",
    "to_be_deleted_at": "2099-01-01T12:00:00Z"
  },
  "accounts": [
    {
      "id": "id_example_001",
      "name": "example",
      "roles": [
        "example"
      ],
      "is_delete_allowed": true,
      "created_at": "2099-01-01T12:00:00Z"
    }
  ]
}
```

### DocumentStatsRow

```json
{
  "period": "example",
  "documents_uploaded": 1,
  "documents_sent": 1,
  "signature_requests": 1,
  "signature_requests_notification_email": 1,
  "signature_requests_notification_whatsapp": 1,
  "signature_requests_notification_bypass": 1,
  "signature_requests_verification_email": 1,
  "signature_requests_verification_whatsapp": 1,
  "signature_requests_verification_bypass": 1,
  "signature_requests_verification_digital_certificate": 1,
  "signature_requests_viewed": 1,
  "signature_requests_completed": 1,
  "documents_certified": 1
}
```

### NotificationPreferences

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
  "SignerWhatsappFailed": true,
  "ContractRenewalNotice": true,
  "ContractExpiring": true,
  "ContractExpired": true,
  "ContractRenewed": true
}
```

### DocumentArtifacts

```json
{
  "original": "https://app.example.invalid/documents/document_example_001/original",
  "thumbnail": "https://app.example.invalid/documents/document_example_001/thumbnail",
  "certificated": "https://app.example.invalid/documents/document_example_001/certificated",
  "certificate-page": "https://app.example.invalid/documents/document_example_001/certificate-page",
  "pades": "https://app.example.invalid/documents/document_example_001/pades",
  "bundle": "https://app.example.invalid/documents/document_example_001/bundle"
}
```


### OAuthRefreshRequest

`POST /v1/oauth/token`, form fields (`application/x-www-form-urlencoded`):

```json
{
  "grant_type": "refresh_token",
  "refresh_token": "rt_example_001",
  "client_id": "client_id_example_001"
}
```

### StartIdentityVerificationPayload

`POST /v1/signers/identity-verification?signer-access-code={code}`. No workspace credential.

```json
{
  "consent": true
}
```

### IdentityVerificationState

`GET /v1/signers/identity-verification?signer-access-code={code}` returns this in `data`:

```json
{
  "can_start": false,
  "status": "Pending",
  "url": "https://verify.example.invalid/c/session_example_001#t=synthetic",
  "expires_at": "2099-01-01T12:00:00Z",
  "completed_at": null
}
```

### IdentityVerificationSession

The start request returns this in `data`. Capture URLs are bearer links; preserve fragments,
open transiently, and never log them or persist them in browser storage.

```json
{
  "id": "session_example_001",
  "url": "https://verify.example.invalid/c/session_example_001#t=synthetic",
  "expires_at": "2099-01-01T12:00:00Z"
}
```

### ReviewIdentityVerificationPayload

`POST /v1/documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/identity-verification/review`.
`decision` is `Approved` or `Rejected`; `note` is optional, nullable, and at most 2,000 characters.

```json
{
  "decision": "Approved",
  "note": "Identity checked by the workspace reviewer."
}
```

### SignerIdentityReview

The workspace `GET .../identity-verification` and `POST .../identity-verification/review`
return this in `data`. Every CPF below is a deliberately invalid synthetic placeholder.
Images are available only during `InReview` through
`GET .../identity-verification/images/{name}` (`document_front`, `document_back`,
`document_pdf`, or `face`), with binary JPEG, PNG, or PDF responses and no request body.
After a decision, `images` is empty; `reviewed_by`, `reviewed_at`, `review_note` and
`completed_at` carry the decision metadata. Evidence can be null or unavailable.

```json
{
  "id": "review_example_001",
  "status": "InReview",
  "provider": "AssinafyVerify",
  "verification_method": "IdDocumentFaceMatchBasic",
  "reason_codes": [{"code": "NAME_MISMATCH", "description": "Name requires review"}],
  "evidence_available": true,
  "expected": {"name": "Example Signer", "cpf": "00000000000"},
  "document": {"type": "CNH", "name": "EXAMPLE SIGNER", "cpf": "00000000000"},
  "matches": {"cpf": true, "name": 0.52, "birth_date": null},
  "checks": [{"name": "name", "result": "review", "score": 0.52, "reasons": ["NAME_MISMATCH"]}],
  "images": ["document_front", "document_back", "face"],
  "ruleset_version": "example-ruleset",
  "evidence_sha256": "0000000000000000000000000000000000000000000000000000000000000000",
  "reviewed_by": null,
  "reviewed_at": null,
  "review_note": null,
  "completed_at": null
}
```

### WebhookURLRequests

`GET /v1/accounts/{accountId}/webhooks/endpoints?url={exactURL}` has no body and
returns `data: [WebhookEndpoint]`; the SDK also filters exact URLs locally for sandbox.
`DELETE` at the same URL has no body and returns the success envelope with `data: []`.
The URL must match the registered URL exactly and is percent-encoded as one query value.

### CreatedWebhookEndpoint

`POST /v1/accounts/{accountId}/webhooks/endpoints` with `signing_enabled: true`
returns the following in `data`. Save `secret` securely on your webhook server;
list and view responses omit it. Enabling signing through `PUT` can also return a
newly generated secret once. OAuth applications cannot retrieve an existing secret;
`webhooks:write` permits rotation, which immediately invalidates the previous secret.

```json
{
  "id": "endpoint_example_001",
  "name": "Marketplace",
  "url": "https://app.example.invalid/hooks/assinafy",
  "email": "ops@example.invalid",
  "events": [
    "signer_identity_review_required",
    "signer_identity_review_approved"
  ],
  "is_active": true,
  "signing_enabled": true,
  "secret": "whsec_c3ludGhldGljLWtleS1mb3ItZG9jdW1lbnRhdGlvbg==",
  "created_at": "2099-01-01T12:00:00Z",
  "updated_at": "2099-01-01T12:00:00Z",
  "is_held": false,
  "held_since": null
}
```

## Contract management

These examples use synthetic document/member/reference IDs and reserved
`example.invalid` URLs. Taxpayer identifiers are null: applications supply the
counterparty's valid CPF/CNPJ when required. Dates illustrate the contract and
are not instructions to submit those dates unchanged.

The operation table uses full `/v1` paths. Successful response examples below
show the complete **data object**, which the API wraps in
`{"status":200,"message":"","data":...}`; the list wraps contract objects in an
array. The error examples show their complete envelopes. Optional expansions
are included in the main contract example and omitted from responses that do
not request or supply them.

| Operation | Request | Response data |
| --- | --- | --- |
| `GET /v1/accounts/{accountId}/contracts` | No body; 12 optional [filters](API_REFERENCE.md#listing-and-synchronization) | Array of [DocumentContract](#documentcontract), pagination in headers |
| `GET /v1/accounts/{accountId}/documents/{documentId}/contract` | No body | [DocumentContract](#documentcontract) or [DocumentContractAmendment](#documentcontractamendment) |
| `PUT /v1/accounts/{accountId}/documents/{documentId}/contract` | [Root update](#updatecontractpayload), [instrument link](#contractamendmentlink), or [explicit nulls](#contractclearfields) | Root terms or amendment link, exposed as `ContractDetails` |
| `GET /v1/accounts/{accountId}/documents/{documentId}/contract/related` | No body | Root [DocumentContract](#documentcontract) with its family |
| `POST /v1/accounts/{accountId}/documents/{documentId}/contract/renew` | [RenewContractPayload](#renewcontractpayload) | [Renewed contract](#documentcontractrenewed) |
| `POST /v1/accounts/{accountId}/documents/{documentId}/contract/terminate` | [TerminateContractPayload](#terminatecontractpayload), or `{}` | [Terminated contract](#documentcontractterminated) |

All routes use workspace credentials. OAuth reads require `documents:read`;
writes require `documents:write` and contract tracking in the workspace's plan.

An illustrative list query containing every supported filter is:

```text
?status=active,expired&counterparty=Example&search=Contract&end_date_from=2026-11-01&end_date_to=2027-10-31&ending_within_days=30&external_system=crm&external_id=deal-1&sort=end_date&expand=document&page=1&per-page=25
```

Each filter narrows the list. `ending_within_days=0` means today in Brasília
time. A list's header metadata may be:

```text
X-Pagination-Current-Page: 1
X-Pagination-Per-Page: 25
X-Pagination-Total-Count: 42
X-Pagination-Page-Count: 2
```

### UpdateContractPayload

All root-term fields, for an existing contract. `counterparty_taxpayer_id: null`
uses `clearFields: ["counterparty_taxpayer_id"]`; an ordinary nil property is
omitted. For initial creation omit `updated_at`, since no prior terms exist.
`parent_document_id` and `relation_type` appear in the instrument examples below
and are not root-term attributes. Together these examples cover all 16 API
update fields.

```json
{
  "status": "active",
  "counterparty_name": "Example Company",
  "counterparty_taxpayer_id": null,
  "value": 1200.5,
  "currency": "BRL",
  "start_date": "2026-11-01",
  "end_date": "2027-10-31",
  "auto_renew": true,
  "renewal_term_months": 12,
  "notice_period_days": 30,
  "owner_id": "member-1",
  "metadata": {
    "crm_stage": "won"
  },
  "external_references": [
    {
      "system": "crm",
      "id": "deal-1"
    }
  ],
  "updated_at": "2026-10-23T12:00:00Z"
}
```

### ContractAmendmentLink

Sent to the amendment document's own PUT route. This includes every term an
`amendment` may change. The explicit null drops the taxpayer-ID delta key and
leaves the parent's taxpayer ID unchanged. For a first link, omit `updated_at`.
For later edits, add the **link's** last-read `updated_at`; omitted delta fields
are retained. Root-only `status`, `owner_id`, and `external_references` do not
belong in an instrument delta.

```json
{
  "parent_document_id": "doc-contract-1",
  "relation_type": "amendment",
  "counterparty_name": "Example Company Updated",
  "counterparty_taxpayer_id": null,
  "value": 1300,
  "currency": "BRL",
  "start_date": "2027-05-01",
  "end_date": "2028-06-30",
  "auto_renew": false,
  "renewal_term_months": 6,
  "notice_period_days": 45,
  "metadata": {
    "crm_stage": "amended"
  }
}
```

### ContractRenewalLink

A signed renewal instrument changes only `end_date` and `value`. It applies on
certification, according to the instrument ordering rules.

```json
{
  "parent_document_id": "doc-contract-1",
  "relation_type": "renewal",
  "end_date": "2029-06-30",
  "value": 1350
}
```

### ContractTerminationLink

A signed termination instrument changes only its effective `end_date`. Omitting
the date uses the signing day. This link is separate from directly calling the
contract termination endpoint.

```json
{
  "parent_document_id": "doc-contract-1",
  "relation_type": "termination",
  "end_date": "2028-01-31"
}
```

### ContractClearFields

Wire representation of `UpdateContractPayload(clearFields: [...])` naming these
nullable root fields. The API still applies the contract's state/date rules;
not every set of cleared terms is valid for every contract. `status` and
`relation_type` cannot be cleared. Clearing `auto_renew` resets it to false;
clearing `currency` restores BRL if a monetary value remains. Clearing
`updated_at` disables the concurrency precondition. To leave a field unchanged,
omit it instead of clearing it. Setting a value and clearing the same key is a
local `ValidationError`.

```json
{
  "counterparty_name": null,
  "counterparty_taxpayer_id": null,
  "value": null,
  "currency": null,
  "start_date": null,
  "end_date": null,
  "auto_renew": null,
  "renewal_term_months": null,
  "notice_period_days": null,
  "owner_id": null,
  "metadata": null,
  "external_references": null,
  "updated_at": null
}
```

### ContractPartialUpdate

Changes the notice period and clears the name; all other fields remain unchanged.
Use `noticePeriodDays: 60`, `updatedAt: ...`, and
`clearFields: ["counterparty_name"]`.

```json
{
  "notice_period_days": 60,
  "counterparty_name": null,
  "updated_at": "2026-10-23T12:00:00Z"
}
```

### ContractExternalReferencesReplacement

Each `ContractExternalReference(system:id:)` has both required strings. This
replaces the whole list; `[]` or explicit null clears it. Sending only the new
item does not append to existing references.

```json
{
  "external_references": [
    {
      "system": "crm",
      "id": "deal-1"
    },
    {
      "system": "erp",
      "id": "contract-1042"
    }
  ]
}
```

### ContractUnlinkPayload

`UpdateContractPayload(updatedAt: ..., clearFields: ["parent_document_id"])`
requests removal of a pending link. The timestamp belongs to the link. Applied
instruments are read-only; a document without an amendment link returns `404`.
A null term on a pending link drops that term from the delta rather than
clearing it on the parent.

```json
{
  "parent_document_id": null,
  "updated_at": "2027-05-10T15:00:00Z"
}
```

### RenewContractPayload

Renews from the current `term` using the configured renewal interval; omitted
`end_date` uses that interval until the next end date is in the future. Omit
`value` to retain the amount. `updated_at` is optional but preserves concurrent
changes. The current term or an explicit new end date is required.

```json
{
  "term": 2,
  "value": 1260,
  "updated_at": "2027-05-12T18:20:00Z"
}
```

### ContractRenewExplicit

All renewal wire fields. `RenewContractPayload(term: 2, endDate: "2029-06-30",
clearsValue: true, updatedAt: ...)` encodes this body. The term may be omitted
when a nonblank end date is supplied. A repeated request cannot renew twice:
the current term or end date no longer matches the request's precondition.

```json
{
  "term": 2,
  "end_date": "2029-06-30",
  "value": null,
  "updated_at": "2027-05-12T18:20:00Z"
}
```

### TerminateContractPayload

Both properties are optional. The default `TerminateContractPayload()` sends
`{}`. The reason is recorded in the termination activity, with HTML stripped;
the SDK rejects more than 500 characters before I/O.

```json
{
  "reason": "Supplier replaced",
  "updated_at": "2026-10-23T12:00:00Z"
}
```

### DocumentContract

Complete contract fields, including the optional expanded document and amendment
family. `document` is included with `expand=document`; `amendments` is included
by single-contract and family reads. The embedded document uses the normal
[Document](#document) shape; its own assignment/page expansion is server-controlled.
`has_contract` is omitted here because it is provided by the workspace's direct
document-detail route, not the contract list expansion.

```json
{
  "resource": "document_contract",
  "document_id": "doc-contract-1",
  "status": "active",
  "counterparty_name": "Example Company",
  "counterparty_taxpayer_id": null,
  "value": 1300,
  "currency": "BRL",
  "start_date": "2026-11-01",
  "end_date": "2028-06-30",
  "auto_renew": false,
  "renewal_term_months": 6,
  "notice_period_days": 45,
  "term": 2,
  "owner_id": "member-1",
  "metadata": {
    "crm_stage": "amended"
  },
  "external_references": [
    {
      "system": "crm",
      "id": "deal-1"
    }
  ],
  "created_at": "2026-10-23T12:00:00Z",
  "updated_at": "2027-05-12T18:20:00Z",
  "document": {
    "resource": "document",
    "id": "doc-contract-1",
    "account_id": "account-1",
    "template_id": null,
    "name": "Service Contract.pdf",
    "status": "certificated",
    "artifacts": {
      "original": "https://example.invalid/documents/doc-contract-1/original.pdf",
      "thumbnail": "https://example.invalid/documents/doc-contract-1/thumbnail.png",
      "certificated": "https://example.invalid/documents/doc-contract-1/certificated.pdf",
      "certificate-page": "https://example.invalid/documents/doc-contract-1/certificate.pdf",
      "bundle": "https://example.invalid/documents/doc-contract-1/bundle.zip"
    },
    "is_closed": true,
    "signing_url": "https://example.invalid/sign/doc-contract-1",
    "verification_code": "verification-example-1",
    "verification_url": "https://example.invalid/verify/verification-example-1",
    "decline_reason": null,
    "declined_by": null,
    "tags": [],
    "created_at": "2026-10-20T14:00:00Z",
    "updated_at": "2026-10-22T09:00:00Z"
  },
  "amendments": [
    {
      "resource": "document_contract_amendment",
      "document_id": "doc-amendment-1",
      "document_name": "Amendment 1.pdf",
      "parent_document_id": "doc-contract-1",
      "relation_type": "amendment",
      "number": 1,
      "status": "applied",
      "document_status": "certificated",
      "apply_error": null,
      "currency": "BRL",
      "terms": {
        "value": 1300,
        "end_date": "2028-06-30"
      },
      "changes": {
        "value": {
          "from": 1200.5,
          "to": 1300
        },
        "end_date": {
          "from": "2027-10-31",
          "to": "2028-06-30"
        },
        "term": {
          "from": 1,
          "to": 2
        }
      },
      "applied_at": "2027-05-12T18:20:00Z",
      "created_at": "2027-05-10T15:00:00Z",
      "updated_at": "2027-05-12T18:20:00Z"
    }
  ]
}
```

### DocumentContractAmendment

A pending instrument, with every amendment response field. `changes` previews
what applying the delta would change. The GET/PUT result is decoded as
`ContractDetails.amendment`; `ContractDetails.contract` is nil. `terms` and
`changes` may themselves be null when the instrument moves no terms. A signed
instrument waiting for an earlier instrument or another condition carries the
reason in `apply_error`.

```json
{
  "resource": "document_contract_amendment",
  "document_id": "doc-amendment-2",
  "document_name": "Amendment 2.pdf",
  "parent_document_id": "doc-contract-1",
  "relation_type": "amendment",
  "number": null,
  "status": "pending",
  "document_status": "pending_signature",
  "apply_error": null,
  "currency": "BRL",
  "terms": {
    "value": 1350,
    "end_date": "2029-06-30"
  },
  "changes": {
    "value": {
      "from": 1300,
      "to": 1350
    },
    "end_date": {
      "from": "2028-06-30",
      "to": "2029-06-30"
    },
    "term": {
      "from": 2,
      "to": 3
    }
  },
  "applied_at": null,
  "created_at": "2028-05-10T15:00:00Z",
  "updated_at": "2028-05-10T15:00:00Z"
}
```

### DocumentContractAmendmentApplied

An applied instrument retains its numbered change record and currency. It
cannot be edited or unlinked. These fields also appear inside a root contract's
`amendments` array.

```json
{
  "resource": "document_contract_amendment",
  "document_id": "doc-amendment-1",
  "document_name": "Amendment 1.pdf",
  "parent_document_id": "doc-contract-1",
  "relation_type": "amendment",
  "number": 1,
  "status": "applied",
  "document_status": "certificated",
  "apply_error": null,
  "currency": "BRL",
  "terms": {
    "value": 1300,
    "end_date": "2028-06-30"
  },
  "changes": {
    "value": {
      "from": 1200.5,
      "to": 1300
    },
    "end_date": {
      "from": "2027-10-31",
      "to": "2028-06-30"
    },
    "term": {
      "from": 1,
      "to": 2
    }
  },
  "applied_at": "2027-05-12T18:20:00Z",
  "created_at": "2027-05-10T15:00:00Z",
  "updated_at": "2027-05-12T18:20:00Z"
}
```

### DocumentContractRenewed

The renewal response uses `DocumentContract`. Unrequested document and amendment
expansions are absent. An expired contract becomes active; a terminated contract
cannot be renewed.

```json
{
  "resource": "document_contract",
  "document_id": "doc-contract-1",
  "status": "active",
  "counterparty_name": "Example Company",
  "counterparty_taxpayer_id": null,
  "value": 1260,
  "currency": "BRL",
  "start_date": "2026-11-01",
  "end_date": "2028-12-30",
  "auto_renew": false,
  "renewal_term_months": 6,
  "notice_period_days": 45,
  "term": 3,
  "owner_id": "member-1",
  "metadata": {
    "crm_stage": "amended"
  },
  "external_references": [
    {
      "system": "crm",
      "id": "deal-1"
    }
  ],
  "created_at": "2026-10-23T12:00:00Z",
  "updated_at": "2028-06-15T09:30:00Z"
}
```

### DocumentContractTerminated

The termination response uses `DocumentContract`. Its underlying document remains
a separate signed artifact; terminating tracking does not cancel that document.

```json
{
  "resource": "document_contract",
  "document_id": "doc-contract-1",
  "status": "terminated",
  "counterparty_name": "Example Company",
  "counterparty_taxpayer_id": null,
  "value": 1300,
  "currency": "BRL",
  "start_date": "2026-11-01",
  "end_date": "2028-06-30",
  "auto_renew": false,
  "renewal_term_months": 6,
  "notice_period_days": 45,
  "term": 2,
  "owner_id": "member-1",
  "metadata": {
    "crm_stage": "amended"
  },
  "external_references": [
    {
      "system": "crm",
      "id": "deal-1"
    }
  ],
  "created_at": "2026-10-23T12:00:00Z",
  "updated_at": "2028-01-31T14:00:00Z"
}
```

The dedicated `value` fields use `NSDecimalNumber` and Foundation `Decimal` for
exact monetary encoding/decoding. Construct inputs with `NSDecimalNumber(string:)`.
Opaque amendment `termsJSON` and `changesJSON` use the existing `JSONValue`:
integers remain integers, fractional numbers use `Double`, and explicit null is
retained. Their Objective-C `terms` and `changes` views use Foundation values and
`NSNull`. Use the root's decimal `value` for exact monetary calculations.

`ContractDetails` is an SDK wrapper, not an extra JSON envelope: the wire `data`
object is the contract or amendment itself.

### ContractInputError

Complete `400` response. `APIError.responseData` retains the `errors` array.
Each stable code belongs to the named field; the top-level message is the first
problem's message. Invalid JSON can return `400` without this array.

```json
{
  "status": 400,
  "message": "value must be no less than 0.",
  "errors": [
    {
      "field": "value",
      "code": "TooSmall",
      "message": "value must be no less than 0."
    },
    {
      "field": "currency",
      "code": "Invalid",
      "message": "currency is invalid."
    }
  ]
}
```

### ContractRenewalConditionError

A repeated term-based renewal. Other whole-request rules may use `field: null`,
for example `AlreadyTerminated`, `ContractTerminated`, or `AmendmentApplied`.
Messages are localized by the platform; branch on status and stable codes.

```json
{
  "status": 400,
  "message": "The contract is no longer in the requested term.",
  "errors": [
    {
      "field": "term",
      "code": "TermMismatch",
      "message": "The contract is no longer in the requested term."
    }
  ]
}
```

### ContractChanged

Complete optimistic-concurrency failure. Nothing was written. Read the root or
link again and reconcile the intended change before using its new `updated_at`.
The SDK does not retry this response.

```json
{
  "status": 409,
  "message": "The contract changed after it was read; read it again and resend the change.",
  "code": "ContractChanged"
}
```

### NoContractTerms

The document exists in the workspace but has no readable terms. A missing or
out-of-workspace document also returns `404`, without this code.

```json
{
  "status": 404,
  "message": "This document has no contract terms.",
  "code": "NoContractTerms"
}
```
