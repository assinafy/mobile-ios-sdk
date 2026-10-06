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
| `POST /v1/documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/estimate-resend-cost` | No body | [CostEstimate](#costestimate) |
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
| `POST /v1/oauth/token` | [JSON](#request-19) | Flat [JSON](#response-9) |
| `POST /v1/oauth/revoke` | [JSON](#request-20) | Empty body |
| `GET /v1/oauth/userinfo` | No body | Flat [JSON](#response-10) |
| `GET /v1/documents/{documentId}/thumbnail` | No body | image/* bytes |
| `GET /v1/documents/{documentId}/pages/{pageId}/download` | No body | image/* bytes |
| `GET /v1/public/documents/{documentId}` | No body | [Document](#document) |
| `PUT /v1/public/documents/{documentId}/send-token` | [JSON](#request-21) | Envelope without data |
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
| `GET /.well-known/oauth-protected-resource` | No body | Flat [JSON](#response-18) |
| `GET /v1/documents/{documentId}/assignments/{assignmentId}/whatsapp-notifications` | No body | Array of [WhatsappNotification](#whatsappnotification) |

OAuth token, revocation, authorization-server discovery and userinfo payloads are
[documented separately](API_REFERENCE.md#oauth-21), including their flat responses
and form encoding. Template create/get/update/delete use
[the template SDK methods](API_REFERENCE.md#templates): creation is multipart
`name` and `file`; updates encode `name`, `document_name`, and `message`;
get/create/update return the `Template` data object; deletion returns an envelope.

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
  ],
  "entries": [
    {}
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
  "SignerWhatsappFailed": true
}
```

### request-19

`POST /v1/oauth/token`

```json
{
  "grant_type": "authorization_code",
  "code": "example",
  "redirect_uri": "https://app.example.invalid/resource",
  "code_verifier": "example",
  "refresh_token": "example",
  "client_id": "client_id_example_001",
  "client_secret": "example",
  "resource": "oauthtokenrequest",
  "subject_token": "example",
  "subject_token_type": "urn:ietf:params:oauth:token-type:access_token",
  "requested_token_type": "urn:ietf:params:oauth:token-type:access_token"
}
```

### request-20

`POST /v1/oauth/revoke`

```json
{
  "token": "example",
  "token_type_hint": "access_token",
  "client_id": "client_id_example_001",
  "client_secret": "example"
}
```

### request-21

`PUT /v1/public/documents/{documentId}/send-token`

```json
{
  "email": "signer@example.invalid"
}
```

### request-22

`POST /v1/accounts/{accountId}/signers`

```json
{
  "full_name": "example",
  "email": "signer@example.invalid",
  "whatsapp_phone_number": null
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
    "example"
  ],
  "is_active": true,
  "url": "https://app.example.invalid/resource",
  "email": "signer@example.invalid"
}
```

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
  "access_token": "example",
  "issued_token_type": "example",
  "token_type": "example",
  "expires_in": 1,
  "refresh_token": "example",
  "scope": "example",
  "id_token": "example"
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
    "account:read", "webhooks:write", "openid", "profile", "email", "offline_access"
  ],
  "bearer_methods_supported": [
    "header"
  ]
}
```

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
    ]
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
  "updated_at": "2099-01-01T12:00:00Z"
}
```

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
  "created_at": "2099-01-01T12:00:00Z"
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
  ]
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
  "credits": 1,
  "needs_extra_document": true,
  "extra_document_cost": 1,
  "total_credits": 1,
  "breakdown": [
    {
      "code": "example",
      "name": "example",
      "cost": 1,
      "quantity": 1,
      "unit_cost": 1
    }
  ],
  "document_balance": 1,
  "credit_balance": 1,
  "has_sufficient_resources": true,
  "blocking_reason": "PendingPayment",
  "message": "Success"
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
    "example"
  ],
  "is_active": true,
  "url": "https://app.example.invalid/resource",
  "email": "signer@example.invalid",
  "updated_at": "2099-01-01T12:00:00Z"
}
```

### WebhookDispatch

```json
{
  "resource": "webhookdispatch",
  "id": "id_example_001",
  "event": "example",
  "activity_id": 1,
  "endpoint": "example",
  "payload": {},
  "delivered": true,
  "http_status": 1,
  "response_body": "example",
  "error": "example",
  "created_at": "2099-01-01T12:00:00Z",
  "updated_at": "2099-01-01T12:00:00Z"
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

### DocumentVerification

```json
{
  "hash": "example",
  "id": "id_example_001",
  "agreement_code": "example",
  "status": "uploaded",
  "page_count": "example",
  "signer_count": "example",
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
  "sent_at": 1,
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
  "SignerWhatsappFailed": true
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
