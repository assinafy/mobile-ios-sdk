# Assinafy iOS SDK API reference

This reference documents every public Swift `async` SDK operation, its exact
HTTP request, decoded result, compatibility behavior, and error surface.
[Complete JSON payload examples](PAYLOADS.md) cover request bodies and response
objects. The authoritative API sources are the
[Assinafy API documentation](https://api.assinafy.com.br/v1/docs) and its
[OpenAPI document](https://api.assinafy.com.br/v1/docs/openapi.json).

Examples in this file are synthetic. They use reserved `example.invalid` addresses
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
- The `/oauth/*` and `/.well-known/*` operations answer **flat** objects with no
  envelope, as RFC 6749 §5.1, OIDC Core §5.3.2, and RFC 8615 require. Their
  failures are flat `{error, error_description}` bodies, readable as
  `APIError.oauthError`.
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
| `AssinafyClient(configuration:)` | Designated client initializer. Exposes `auth`, `workspaces`, `signers`, `documents`, `assignments`, `templates`, `tags`, `fields`, `webhooks`, `oauth`, and `contracts`. |
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
| `login(_:)` | Public | `POST /login`; JSON `email` and `password`, both required | `data: AuthSession` -> `LoginResponse`; a `data.mfa_token` challenge throws `MFARequiredError` |
| `socialLogin(_:)` | Public | `POST /authentication/social-login`; JSON `provider` (`google`), `token`, and `has_accepted_terms`, all required | `data: AuthSession` -> `LoginResponse`; a `data.mfa_token` challenge throws `MFARequiredError` |
| `verifyMFA(_:)` | Public | `POST /authentication/mfa/verify`; required JSON `mfa_token` and `code` (6-digit authenticator code or recovery code) | `data: AuthSession` -> `LoginResponse` |
| `mfaStatus()` | Account | `GET /users/self/mfa` | `data: {methods: [MFAMethod], recovery_codes_remaining: integer}` -> `MFAStatus` |
| `enrollTOTP(label:)` | Account | `POST /users/self/mfa/totp`; optional JSON `label` | `data: {id, secret, provisioning_uri}` -> `TOTPEnrollment` |
| `confirmTOTP(_:)` | Account | `PUT /users/self/mfa/totp/confirm`; required `id`, `code`; `password` or `reauth_code` only when replacing a confirmed method | `data.recovery_codes: [string]` -> `[String]` |
| `regenerateRecoveryCodes(_:)` | Account | `POST /users/self/mfa/recovery-codes`; `password` and/or `code`, at least one required by the SDK | `data.recovery_codes: [string]` -> `[String]` |
| `removeMFAMethod(id:_:)` | Account | `DELETE /users/self/mfa/{id}`; JSON body `password` and/or `code`, at least one required by the SDK | `data.is_mfa_enabled: boolean` -> `Bool` |
| `linkSocialLogin(_:)` | Account | `POST /auth/link-social-login`; JSON `provider` (`google`) and `token`, both required | Bare envelope; returns `Void` |
| `currentUser()` | Account | `GET /users/self` | `data` is a direct `AuthUser`, normalized to `SelfResponse(user: data, accounts: [])`. The decoder also accepts the former `{user, accounts}` data wrapper. |
| `currentUserProfile()` | Account | `GET /users/self` | Returns `User`; accepts both documented direct `data: User` and the sandbox compatibility `{user, accounts}` wrapper. |
| `getNotificationPreferences()` | Account | `GET /users/self/notification-preferences` | `data: NotificationPreferences` |
| `updateNotificationPreferences(_:)` | Account | `PUT /users/self/notification-preferences`; partial `NotificationPreferences` JSON; at least one key is required by the SDK | The complete updated `NotificationPreferences` |
| `stats(params:)` | Account | `GET /users/self/stats`; optional `granularity=monthly\|daily`, `month=YYYY-MM` | `[DocumentStatsRow]` |
| `changePassword(_:)` | Account | `PUT /authentication/change-password`; required JSON `email`, `password`, `new_password` | Documented `data.email`; SDK returns `Void` |
| `changePasswordAndReturnResponse(_:)` | Account | Same request as `changePassword(_:)` | Canonical `EmailResponse` with `email` |
| `requestPasswordReset(_:)` | Public | `PUT /authentication/request-password-reset`; required JSON `email` | Documented `data.email`; SDK returns `Void` |
| `requestPasswordResetAndReturnResponse(_:)` | Public | Same request as `requestPasswordReset(_:)` | Canonical `EmailResponse` with `email` |
| `resetPassword(_:)` | Public | `PUT /authentication/reset-password`; required JSON `email`, `new_password`; optional `token` | Documented `data.email`; SDK returns `Void` |
| `resetPasswordAndReturnResponse(_:)` | Public | Same request as `resetPassword(_:)` | Canonical `EmailResponse` with `email` |
| `getAPIKey()` | Account | `GET /users/api-keys` | `data.api_key: string\|null`; SDK returns `String?` |
| `createAPIKey(_:)` | Account | `POST /users/api-keys`; required JSON `password` | `data.api_key: string\|null`; SDK requires a nonempty value and returns `String` |
| `deleteAPIKey()` | Account | `DELETE /users/api-keys` | Documented `data: []`; returns `Void` |

Two-factor login: `login(_:)` throws `MFARequiredError` carrying `mfaToken`.
The challenge is single-use and expires five minutes after login. Pass it with
the user's code to `verifyMFA(_:)`, which returns the session. Objective-C
receives `NSError` in `ASFErrorDomain.mfaRequired` (code `401`) with
`userInfo["mfaToken"]`. `TOTPEnrollment.secret` and the recovery codes from
`confirmTOTP(_:)` and `regenerateRecoveryCodes(_:)` are returned only once.

`NotificationPreferences` exposes thirteen Boolean wire keys. Updates accept any
nonempty subset. The four contract preferences default to `true` when absent from
an older response; the nine-argument initializer uses the same defaults.

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

`ContractRenewalNotice` covers the notice period before an end or renewal;
`ContractExpiring` covers 45-day and 30-day expiry reminders; `ContractExpired`
covers expiry without renewal; `ContractRenewed` covers automatic renewal.
Personal profile, notification preferences and user-wide statistics are unavailable
to third-party OAuth applications. Use `oauth.userInfo()` for identity claims and
`workspaces.stats(params:accountId:)` for workspace statistics.

## OAuth 2.1

All methods are available through `client.oauth`. The flow is the RFC 6749
authorization code grant with **mandatory PKCE (S256)**; the server accepts no
other challenge method. A mobile app is a public client: it sends `client_id`
with no `client_secret`, and every `clientSecret` parameter below stays `nil`.

**These endpoints are deployed on production only.** The sandbox host answers
`403` for the well-known path and `404` for `/oauth/token`.

| Async SDK method | Auth | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `protectedResourceMetadata()` | Public | `GET {host}/.well-known/oauth-protected-resource` at the **host root**, outside `/v1` | Flat object -> `OAuthProtectedResourceMetadata` |
| `authorizationServerMetadata(issuer:)` | Public | `GET {issuer}/.well-known/oauth-authorization-server` on the authorization server's own host | Flat object -> `OAuthAuthorizationServerMetadata` |
| `exchangeAuthorizationCode(_:)` | Public | `POST /oauth/token`; form body below with `grant_type=authorization_code` | Flat object -> `OAuthTokenResponse` |
| `refreshAccessToken(_:)` | Public | `POST /oauth/token`; form body below with `grant_type=refresh_token` | Flat object -> `OAuthTokenResponse` |
| `revoke(_:)` | Public | `POST /oauth/revoke`; form fields `token`, `client_id` required, optional `token_type_hint`, `client_secret` | Empty `200`; returns `Void` |
| `userInfo()` | Account | `GET /oauth/userinfo`, presenting the OAuth access token as the bearer credential | Flat claims object -> `OAuthUserInfo` |

`authorizationURL(for:)` and `OAuthAuthorizationRequest.authorizationURL(endpoint:)`
build a URL locally and send no request.

### Authorization request

`OAuthAuthorizationRequest` produces this query against the authorization
endpoint (`https://auth.assinafy.com.br/oauth/authorize`):

| Parameter | Value |
| --- | --- |
| `response_type` | Always `code` |
| `client_id` | The registered client identifier |
| `redirect_uri` | The registered `https://` redirect URI, matched exactly |
| `state` | 43 BASE64URL characters of CSPRNG output, single-use |
| `code_challenge` | BASE64URL(SHA256(`code_verifier`)) |
| `code_challenge_method` | Always `S256` |
| `scope` | Space-separated scopes; omitted when empty |
| `resource` | RFC 8707 resource indicator; omitted when `nil` |

The `code_verifier` is **never** sent here. `OAuthCallback.validate(against:issuer:)`
then checks the callback, `state` and `iss` first on approvals and error
redirects alike: it throws `ValidationError` on a `state` mismatch (compared in
constant time) on duplicate security parameters or conflicting `code`/`error`, or on a missing `iss` or one other than the expected issuer
(`OAuthResource.defaultIssuer` when none is passed); then `APIError` carrying
the server's `error`; then `ValidationError` when no code is present.
Callback queries use form decoding: `+` means a space and `%2B` means a literal
plus. Authorization URLs and API queries encode literal plus signs as `%2B`.

### Token request

A PKCE verifier contains 43–128 unreserved ASCII characters (`A-Z`, `a-z`,
`0-9`, `-`, `.`, `_`, `~`). The exchange method accepts only the authorization-code
grant, and refresh accepts only the refresh-token grant; validation precedes I/O.

The body is `application/x-www-form-urlencoded`, fields sorted by name, with
every character outside `A-Z a-z 0-9 - . _ ~` percent-encoded:

```text
client_id=cli_2b9e44d1&code=ac_7f3c1d92b4a64e08&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk&grant_type=authorization_code&redirect_uri=https%3A%2F%2Fapp.example.invalid%2Foauth%2Fcallback&resource=https%3A%2F%2Fapi.assinafy.com.br
```

```text
client_id=cli_2b9e44d1&grant_type=refresh_token&refresh_token=rt_6a2f08c5e1b74d39
```

`code`, `redirect_uri`, `code_verifier`, `refresh_token`, `client_secret`, and
`resource` are omitted when `nil`. Each request is sent once, follows no
redirect, and is never retried: a code is single-use and expires 60 seconds
after approval, and a retried or redirected refresh could resend a refresh token
the first attempt already retired. A `3xx` answer throws `APIError` carrying
that status. The SDK validates locally before sending:
`client_id` must be non-blank; the authorization-code grant requires a non-blank
`code` and `redirect_uri` and a `code_verifier` of 43–128 characters; the
refresh grant requires a non-blank `refresh_token`. Any other `grant_type` is
rejected as `ValidationError`.

### Token response

```json
{
  "access_token": "at_9d41c7be20f5486a",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "rt_6a2f08c5e1b74d39",
  "scope": "documents:read documents:write",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

`refresh_token` is present only when `offline_access` was requested **and**
consented. `id_token` is present only when `openid` was granted; the SDK does
not validate it. `scope` lists the access token's scopes and never contains
`offline_access`, which is a request-time signal rather than a permission, so
whether a refresh token was issued is read from `refresh_token`, never `scope`.
`OAuthTokenResponse` adds `issuedAt` (decode time), `expiresAt`, `scopes`, and
`isExpired(leeway:)`, defaulting to 60 seconds of headroom.

Every refresh returns a new `refresh_token`, valid for a fresh 30 days, and
retires the one sent; a connection expires only after 30 days without a
refresh. `refreshAccessToken(_:)` throws `AssinafySDKError` when a successful
response carries no `refresh_token`, a blank one, or the one sent. Persist the
new refresh token before using the response, and never send a retired one:
reuse ends the whole connection. Refresh one at a time per connection.

A refresh that fails without an OAuth error — a timeout, lost connection,
cancellation, `3xx`, `5xx`, or a response without a new refresh token — may
still have retired the token sent. Continue only with a different refresh token
saved since; if the stored one is still the token sent, never send it again and
ask the user to connect again. Only a `NetworkError` whose underlying `URLError`
code is `cannotFindHost`, `dnsLookupFailed`, `cannotConnectToHost`,
`secureConnectionFailed`, or a `serverCertificate…` code shows that the request
never left, so only that failure is safe to retry.

### Revocation request

```text
client_id=cli_2b9e44d1&token=rt_6a2f08c5e1b74d39&token_type_hint=refresh_token
```

Revoke the refresh token saved last; every earlier one is already retired.
Every token outcome answers `200` — revoked, already revoked, unknown, or
malformed — so the endpoint cannot reveal whether a token exists. Only failed
client authentication answers `401 invalid_client`.

### Userinfo response

```json
{
  "sub": "d6zqpbyog2v3xvxerwn8la94",
  "name": "Maria Silva",
  "email": "maria@example.invalid",
  "email_verified": true
}
```

`sub` is always present and requires `openid`; `name` requires `profile`;
`email` and `email_verified` require `email`. Absent claims decode to `nil`.

### Discovery responses

```json
{
  "resource": "https://api.assinafy.com.br",
  "authorization_servers": ["https://auth.assinafy.com.br"],
  "scopes_supported": ["documents:read", "documents:write", "templates:read",
                       "templates:write", "account:read", "webhooks:write", "openid", "profile", "email"],
  "bearer_methods_supported": ["header"]
}
```

`scopes_supported` here deliberately excludes `offline_access`: requesting a
refresh token is a client concern, not something the resource is protected by.
The authorization server's own document does list it.

```json
{
  "issuer": "https://auth.assinafy.com.br",
  "authorization_endpoint": "https://auth.assinafy.com.br/oauth/authorize",
  "token_endpoint": "https://api.assinafy.com.br/v1/oauth/token",
  "revocation_endpoint": "https://api.assinafy.com.br/v1/oauth/revoke",
  "userinfo_endpoint": "https://api.assinafy.com.br/v1/oauth/userinfo",
  "jwks_uri": "https://auth.assinafy.com.br/.well-known/jwks.json",
  "scopes_supported": ["documents:read", "documents:write", "templates:read",
                       "templates:write", "account:read", "webhooks:write", "openid", "profile",
                       "email", "offline_access"],
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "code_challenge_methods_supported": ["S256"],
  "token_endpoint_auth_methods_supported": ["client_secret_post", "none"],
  "authorization_response_iss_parameter_supported": true
}
```

### Scopes

| Scope | Grants |
| --- | --- |
| `documents:read` | Read documents, their pages, tags, signers, assignments, and activity |
| `documents:write` | Create, update, and delete documents, and manage their signers, assignments, and activity |
| `templates:read` | Read templates, their pages, roles, fields, and tags |
| `templates:write` | Create, update, and delete templates, their pages, roles, fields, and tags |
| `account:read` | Read the workspace profile, theme, logo, statistics, and webhook endpoints |
| `webhooks:write` | Manage webhook subscriptions and endpoints, retry deliveries, and rotate signing secrets |
| `openid` | Identify the user and enable `GET /oauth/userinfo` |
| `profile` | Include the user's name in `id_token` and userinfo claims |
| `email` | Include the user's email and verification status in the claims |
| `offline_access` | Issue a refresh token; granted only to a client that asks for it |

An OAuth token cannot reach billing, account lifecycle, credential management,
personal settings, or admin surfaces regardless of its scopes. Biometric review
summaries permit `documents:read`; evidence images and review decisions require
the workspace's own authenticated interface. Reading an existing webhook signing
secret is blocked, while rotating it permits `webhooks:write`.
A missing scope answers `403` with
`WWW-Authenticate: Bearer error="insufficient_scope", scope="…"`;
`APIError.insufficientScope` returns that scope, to request when the user
connects again. It is `nil` for a `403` without the challenge (another
workspace, the user's role, or an area OAuth tokens never reach).

### Error surface

Failures are flat, not enveloped. `APIError.oauthError` exposes them as
`OAuthErrorDetail(code:description:)`.

| Status | `error` | Cause |
| --- | --- | --- |
| `400` | `invalid_grant` | Bad, expired, replayed, or wrong-client code; a `code_verifier` outside the 43–128 unreserved-character grammar; `redirect_uri` mismatch; a refresh token already used, expired, or revoked, or issued before the user approved the app again with different permissions. On a refresh the connection is over: ask the user to connect again |
| `400` | `invalid_target` | A `resource` this server does not issue tokens for, or one disagreeing with the authorized value |
| `400` | `unsupported_grant_type` | A grant type the server does not implement |
| `401` | `invalid_client` | Unknown or disabled client, or failed client authentication. The description never reveals whether the `client_id` exists |

## Workspaces (accounts)

All methods are available through `client.workspaces` and require account auth.

| Async SDK method | Exact request | Wire response and SDK result |
| --- | --- | --- |
| `create(_:)` | `POST /accounts`; required JSON `name`; optional `notification_sender_type=User\|Account` | `data: Account` -> `WorkspaceResponse` |
| `list(params:)` | `GET /accounts`; no query is emitted | `[Account]` -> `PaginatedResult<WorkspaceListItem>` |
| `get(workspaceId:)` | `GET /accounts/{workspaceId}` | `Account` -> `WorkspaceResponse` |
| `update(workspaceId:payload:)` | `PUT /accounts/{workspaceId}`; partial JSON `name`, `notification_sender_type=User\|Account` | Updated `Account` |
| `delete(workspaceId:force:)` | `DELETE /accounts/{workspaceId}`; JSON `force: boolean` | Documented `data: []`; returns `Void` |
| `theme(accountId:)` | `GET /accounts/{accountId}/theme` | `AccountTheme` |
| `stats(params:accountId:)` | `GET /accounts/{accountId}/stats`; optional `granularity=monthly\|daily`, `month=YYYY-MM` | `[DocumentStatsRow]` |
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
| `create(_:accountId:)` | Account | `POST /accounts/{accountId}/signers`; required `full_name`; optional `email`, `whatsapp_phone_number`, `government_id` | `Signer`. If `email` is present, the SDK first searches and reuses an exact case-insensitive match. Full-name-only creation is supported. |
| `get(signerId:accountId:)` | Account | `GET /accounts/{accountId}/signers/{signerId}` | `Signer` |
| `list(params:accountId:)` | Account | `GET /accounts/{accountId}/signers`; v1 values are optional `search`, `page`, `per-page`; generic `ListParams` also forwards nonempty compatibility `sort` and caller-defined `extra` | `PaginatedResult<Signer>` |
| `update(signerId:payload:accountId:)` | Account | `PUT /accounts/{accountId}/signers/{signerId}`; partial `full_name`, `email`, `whatsapp_phone_number`, `government_id` | Updated `Signer` |
| `delete(signerId:accountId:)` | Account | `DELETE /accounts/{accountId}/signers/{signerId}` | Documented `data: []`; returns `Void` |
| `findByEmail(_:accountId:)` | Account | Helper over signer list with `search={email}&per-page=100`; follows pagination headers and filters returned emails case-insensitively | Matching `Signer?`; a 404 becomes `nil` |
| `getSelf(signerAccessCode:)` | Signer | `GET /signers/self?signer-access-code={code}` | `SignerSelf` -> `SignerSelfInfo` |
| `acceptTerms(signerAccessCode:)` | Signer | `PUT /signers/accept-terms?signer-access-code={code}`; no JSON body | Bare envelope. The source-compatible `AcceptTermsResponse` is synthesized as `fullName: ""`, `email: ""`, `hasAcceptedTerms: true`; a legacy response body is still decoded. |
| `acceptTermsWithoutResponse(signerAccessCode:)` | Signer | Same request as `acceptTerms(signerAccessCode:)` | Canonical bare-envelope handling; returns `Void` |
| `verifyEmail(payload:)` | Signer | `POST /verify?signer-access-code={code}`; JSON contains only `verification-code` | Bare envelope; returns `Void`. `signerAccessCode` is never emitted in the body. |
| `uploadSignature(signerAccessCode:type:imageData:reuse:)` | Signer | `POST /signature?signer-access-code={code}&type=signature\|initial[&reuse=true]`; body is PNG bytes (`image/png`) | Bare envelope; returns `Void` |
| `uploadSignature(signerAccessCode:type:imageData:reusePreference:)` | Signer | Same request; `true` sends `reuse=true`, `false` sends `reuse=false`, and `nil` omits the preference | Bare envelope; returns `Void`. The older `reuse: false` overload omits the preference and preserves the server's existing choice |
| `downloadSignature(signerAccessCode:type:)` | Signer | `GET /signature/{signatureType}?signer-access-code={code}` where the path value is `signature` or `initial` | Raw image `Data`; there is no redundant `type` query |
| `getCurrentDocument(signerId:signerAccessCode:)` | Signer | `GET /signers/{signerId}/document?signer-access-code={code}` | `Document` -> `DocumentDetails`; the API omits pages and limits assignment items to this signer |
| `listSignerDocuments(signerId:signerAccessCode:params:)` | Signer | `GET /signers/{signerId}/documents?signer-access-code={code}`; v1 query values are `page`, `per-page`; the SDK also forwards compatibility `status`, `method`, `search`, `sort` | `PaginatedResult<DocumentDetails>` |
| `listDocumentsAsWorkspace(signerId:params:)` | Account | `GET /signers/{signerId}/documents` with the workspace credential and no access code; query `page`, `per-page`; the signer must belong to the credential's workspace | `PaginatedResult<DocumentDetails>` |
| `searchDocumentsAsWorkspace(signerId:search:)` | Account | `GET /signers/{signerId}/documents/search` with the workspace credential; optional `search` | `PaginatedResult<DocumentDetails>` (compact documents) |
| `searchSignerDocuments(signerId:signerAccessCode:search:status:)` | Signer | `GET /signers/{signerId}/documents/search?signer-access-code={code}`; v1 defines optional `search`; the SDK also forwards compatibility `status` | `PaginatedResult<DocumentDetails>` |
| `signMultipleDocuments(signerAccessCode:documentIds:)` | Signer | `PUT /signers/documents/sign-multiple?signer-access-code={code}`; JSON `document_ids: [string]`, nonempty | Bare envelope; returns `Void` |
| `declineMultipleDocuments(signerAccessCode:documentIds:reason:)` | Signer | `PUT /signers/documents/decline-multiple?signer-access-code={code}`; JSON `document_ids: [string]`, `decline_reason: string` | Bare envelope; returns `Void` |
| `downloadSignerDocumentArtifact(signerId:documentId:artifact:)` | Public | `GET /signers/{signerId}/documents/{documentId}/download/{artifact}` | Raw PDF `Data` |
| `downloadSignerDocumentArtifact(signerId:documentId:artifact:signerAccessCode:)` | Public | Compatibility overload of the preceding operation; the supplied code is intentionally not sent | Raw PDF `Data` |
| `getSigningDocument(signerAccessCode:hasAcceptedTerms:)` | Signer | `GET /sign?signer-access-code={code}`; optional `has_accepted_terms=true\|false` | `DocumentDetails` |

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
| `list(params: DocumentListParams, accountId:)` | Account | Same path; optional `status`, `method=virtual\|collect`, `search`, `tags` (comma-separated tag IDs), `sort`, `page`, `per-page` | `PaginatedResult<DocumentListItem>` |
| `search(search:status:accountId:)` | Account | `GET /accounts/{accountId}/documents/search`; optional `search`, `status` | Lightweight `PaginatedResult<DocumentListItem>`; preserved source-compatible overload |
| `search(search:status:page:perPage:accountId:)` | Account | Same path; optional `search`, `status`; required Swift pagination arguments below `1` are omitted, otherwise emit `page`, `per-page` | Same result |
| `search(search:status:sort:page:perPage:accountId:)` | Account | Same path; optional `search`, `status`, `sort=name\|updated_at` (prefix `-` for descending), and positive `page`, `per-page`; the optional `sort` argument is explicit | Same result |
| `get(documentId:)` | Account | `GET /documents/{documentId}` | `Document` -> `DocumentDetails` |
| `rename(documentId:name:)` | Account | `PATCH /documents/{documentId}`; JSON `{ "name": string }` | Updated `DocumentDetails` |
| `waitUntilReady(documentId:options:)` | Account | Local polling helper over `GET /documents/{documentId}` | Returns `DocumentUploadResponse` at `metadata_ready`, `pending_signature`, `pending_identity_review`, `certificating`, or `certificated`; throws `AssinafySDKError` on `failed`, `expired`, `rejected_by_signer`, `rejected_by_user`, or timeout; invalid intervals throw `ValidationError` |
| `downloadArtifact(documentId:artifact:)` | Account | `GET /documents/{documentId}/download/{artifact}` | Raw PDF/ZIP `Data` |
| `downloadThumbnail(documentId:)` | Account | `GET /documents/{documentId}/thumbnail` | Raw image `Data` |
| `downloadPage(documentId:pageId:)` | Account | `GET /documents/{documentId}/pages/{pageId}/download` | Raw image `Data` |
| `activities(documentId:)` | Account | `GET /documents/{documentId}/activities`; default first page of 20, newest first | `[DocumentActivity]` |
| `activities(documentId:params:)` | Account | Same path; required `ListParams` argument supports positive `page`, `per-page`, and `sort=id` or `-id` | `PaginatedResult<DocumentActivity>` with pagination headers |
| `delete(documentId:)` | Account | `DELETE /documents/{documentId}` | Documented `data: []`; returns `Void` |
| `createFromTemplate(templateId:signers:options:accountId:)` | Account | `POST /accounts/{accountId}/templates/{templateId}/documents`; body below | `Document` -> `DocumentUploadResponse` |
| `estimateCostFromTemplate(templateId:signers:accountId:)` | Account | `POST /accounts/{accountId}/templates/{templateId}/documents/estimate-cost`; exact estimate body below | `CostEstimate` |
| `verify(signatureHash:)` | Public | `GET /documents/{signatureHash}/verify` | Projects `DocumentVerification.is_valid` to `Bool` |
| `verifyDetails(signatureHash:)` | Public | Same request | Full `DocumentVerification` |
| `isFullySigned(documentId:)` | Account | Local helper over `GET /documents/{documentId}` | `summary.completed_count >= summary.signer_count && signer_count > 0` |
| `getSigningProgress(documentId:)` | Account | Local helper over `GET /documents/{documentId}` | `SigningProgress(signed, total, pending, percentage)` from assignment summary |
| `listStatuses()` | Account | `GET /documents/statuses` | `[DocumentStatusInfo]` (`code`, `deletable`) |
| `getPublicInfo(documentId:)` | Public | `GET /public/documents/{documentId}` | Full `Document` -> `PublicDocumentInfo`, not a four-field summary |
| `sendPublicSignToken(documentId:email:)` | Public | `PUT /public/documents/{documentId}/send-token`; required body `{ "channel": "email", "recipient": string }` | Returns `Void` after one request |
| `sendPublicSignToken(documentId:payload:)` | Public | Same `PUT` and body; `SendTokenPayload.channel` must be `.email` (other channels throw `ValidationError` before I/O) | `data: { "document": { "resource", "id", "name", "page_count", "created_by" }, "channel": "email", "recipient": string }` -> `SendTokenResponse` |
| `confirmSignerDataAndReturnSigner(documentId:signerAccessCode:payload:)` | Signer | `PUT /documents/{documentId}/signers/confirm-data?signer-access-code={code}`; body may contain `full_name`, `email`, `government_id`; compatibility keys are described below | Canonical `data: Signer` result |
| `confirmSignerData(documentId:signerAccessCode:payload:)` | Signer | Same request | Source-compatible overload that validates success and discards `data`; returns `Void` |

For document creation from a template, every signer requires `role_id` and either
an existing signer `id` or `email`. Email reuses a matching signer or creates one;
optional `name` and `whatsapp_phone_number` apply only to a newly created signer.
Other optional signer keys are `verification_method=Email|Whatsapp|DigitalCertificate|IdDocumentFaceMatchBasic`,
`notification_methods: [Email|Whatsapp]`, and positive `step`. Optional top-level
keys are `editor_fields: [{field_id, value}]`, `name`, `message`, `expires_at`,
and `tags`. Here, and only here, `tags` are tag **names** that the API may create;
the document-tag attachment endpoints use tag IDs.

Creation returns an `uploaded` document before background processing completes;
`assignment` can be null until it reaches `pending_signature`. Processing failures
produce `failed` without charging the document. Poll the document before reading
its assignment or signing links.

`DigitalCertificate` may be assigned only through a template with no placed
signer fields. The API derives a `collect` assignment from any such placement,
and certificate signers require the generated assignment to be `virtual`.

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

Only `role_id` is required. Signer IDs, email, name, phone number, signing steps,
editor values, document metadata, expiry, and tags are not part of the estimate request.

For new email-token integrations, use the one-request `email:` overload. The
payload overload returns the typed email `SendTokenResponse` in the same request;
it rejects the WhatsApp channel before I/O. `ConfirmSignerDataPayload` omits every `nil` optional field and
emits `has_accepted_terms` only when `true`; `whatsapp_phone_number` and
`has_accepted_terms` are compatibility fields accepted by signing flows.

## Assignments

Owner operations require account auth. Signing and decline operations require
signer auth.

| Async SDK method | Auth | Exact request | Wire response and SDK result |
| --- | --- | --- | --- |
| `list(params:accountId:)` | Account | `GET /assignments`; optional `page`, `per-page`, `sort=created_at\|expires_at\|id` (prefix `-` for descending); `accountId` is emitted from the explicit argument or client default on every host; required for API keys and session tokens, optional for OAuth tokens scoped to one workspace | `PaginatedResult<Assignment>` |
| `create(documentId:payload:)` | Account | `POST /documents/{documentId}/assignments`; exact body below | `Assignment` |
| `estimateCost(documentId:payload:)` | Account | `POST /documents/{documentId}/assignments/estimate-cost`; exact estimate body below | `CostEstimate` |
| `resetExpiration(documentId:assignmentId:newExpiresAt:)` | Account | `PUT /documents/{documentId}/assignments/{assignmentId}/reset-expiration`; canonical JSON `{ "expires_at": string }`; a blank value is rejected locally | Updated `Assignment` |
| `resetExpiration(documentId:assignmentId:expiresAt:)` | Account | Compatibility overload of the same `PUT`; sends `{ "expires_at": string\|null }`, including explicit JSON `null` when omitted | Updated `Assignment` |
| `resendNotification(documentId:assignmentId:signerId:)` | Account | `PUT /documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/resend`; no body | `ResendNotificationResponse` |
| `estimateResendCost(documentId:assignmentId:signerId:)` | Account | `POST /documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/estimate-resend-cost`; no body | Reminder shape `{total, breakdown, credit_balance, has_sufficient_credits}` decoded as `CostEstimate` |
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

`DigitalCertificate` signers require `method: virtual`. Certificate signing
completes the signer's virtual item through the hosted Web PKI flow; the ordinary
field-signing endpoint does not accept certificate signers, so a `collect`
assignment containing one cannot be completed. Both `create` and `estimateCost`
reject that combination before network I/O with `ValidationError` and the stable
field code `errors["method"] = "digital_certificate_requires_virtual_assignment"`.

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

The assignment list operation accepts `page`, `per-page` and `sort`; leave generic
`ListParams.search` and `extra` unset unless the server supports the supplied values.
The workspace query key is camelCase `accountId` on both production and sandbox.
The SDK uses the explicit argument before `defaultAccountId`; OAuth may derive the
workspace from the access token when both are absent.

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
| `validate(fieldId:value: String, signerAccessCode:accountId:)` | `POST /accounts/{accountId}/fields/{fieldId}/validate`; JSON `{ "value": string }`. Without `signerAccessCode` the workspace credential is sent; with one, only `signer-access-code` is sent (an empty code throws before I/O) | `FieldValidationResult` |
| `validate(fieldId:value: JSONValue, signerAccessCode:accountId:)` | Same path and query; `value` preserves its string, integer, unsigned integer, number, Boolean, object, array, or null JSON type | `FieldValidationResult` |
| `validateMultiple(items: [FieldValidateMultipleItem], signerAccessCode:accountId:)` | `POST /accounts/{accountId}/fields/validate-multiple`; nonempty top-level array of `{field_id: string, value: string}`; signer code handled as in `validate` | `[FieldValidationResult]`; each item also carries `field_id` |
| `validateMultiple(items: [FieldJSONValidationItem], signerAccessCode:accountId:)` | Same request with each `value: JSONValue`, preserving the JSON type | `[FieldValidationResult]` |
| `listFieldTypes()` | `GET /field-types` | `[FieldTypeInfo]` |

The SDK retains these compatibility fields:

- Create sends `is_active: false` when requested; `true` is omitted as the
  default.
- Update may send `type` and `is_required`. `clearsRegex` sends `regex: null`.
- `validate` and `validateMultiple` append `signer-access-code={code}` when a
  nonempty code is supplied.

## Webhooks

All webhook methods require account auth. A workspace has one endpoint, or up
to three on paid plans; `WorkspaceResponse.limits?.webhookEndpoints` exposes the
configured limit when returned. The `subscriptions` routes act on the oldest endpoint;
the `endpoints` routes manage each one.

| Async SDK method | Exact request | Wire response and SDK result |
| --- | --- | --- |
| `listEndpoints(accountId:)` | `GET /accounts/{accountId}/webhooks/endpoints`; scope `account:read` | `data: [WebhookEndpoint]`, oldest first -> `[WebhookEndpoint]` |
| `createEndpoint(_:accountId:)` | `POST /accounts/{accountId}/webhooks/endpoints`; required `url`, `email`, `events`; optional `name`, `is_active` (default `true`), `signing_enabled` (default `false`); scope `webhooks:write` | `WebhookEndpoint`, including one-time `secret` when signing is enabled. `403` past the plan limit; `400` when another endpoint uses the URL |
| `getEndpoint(id:accountId:)` | `GET /accounts/{accountId}/webhooks/endpoints/{endpointId}`; scope `account:read` | `WebhookEndpoint` |
| `updateEndpoint(id:_:accountId:)` | `PUT /accounts/{accountId}/webhooks/endpoints/{endpointId}`; any nonempty subset of `url`, `email`, `events`, `name`, `is_active`, `signing_enabled`; scope `webhooks:write` | Updated `WebhookEndpoint`. Enabling signing returns a newly generated secret once if none exists; disabling discards it |
| `deleteEndpoint(id:accountId:)` | `DELETE /accounts/{accountId}/webhooks/endpoints/{endpointId}`; scope `webhooks:write` | Documented `data: []`; returns `Void` |
| `signingSecret(endpointId:accountId:)` | `GET /accounts/{accountId}/webhooks/endpoints/{endpointId}/secret`; not available to OAuth applications | `data.secret` (`whsec_…`) -> `String`; `400` when signing is disabled |
| `rotateSigningSecret(endpointId:accountId:)` | `POST /accounts/{accountId}/webhooks/endpoints/{endpointId}/secret/rotate`; scope `webhooks:write` | New `data.secret` -> `String`; the old secret stops working immediately |
| `register(_:accountId:)` | `PUT /accounts/{accountId}/webhooks/subscriptions`; required `events: [string]`, `is_active: boolean`, `url: URI`, `email: email` | `WebhookSubscription` |
| `get(accountId:)` | `GET /accounts/{accountId}/webhooks/subscriptions` | `WebhookSubscription` |
| `delete(accountId:)` | Deprecated SDK alias for `PUT /accounts/{accountId}/webhooks/inactivate`; the API has no destructive subscription delete | Response discarded; returns `Void` |
| `inactivate(accountId:)` | `PUT /accounts/{accountId}/webhooks/inactivate`; no body | Documented updated `WebhookSubscription` is discarded; returns `Void` |
| `inactivateAndReturn(accountId:)` | Same request | Updated `WebhookSubscription` |
| `listEventTypes()` | `GET /webhooks/event-types` | `[WebhookEventTypeInfo]` |
| `listDispatches(params:accountId:)` | `GET /accounts/{accountId}/webhooks`; optional `event`, `endpoint_id`, `delivered=true\|false`, `from`, `to`, `page`, `per-page` | `PaginatedResult<WebhookDispatch>` |
| `retryDispatch(dispatchId:accountId:)` | `POST /accounts/{accountId}/webhooks/{historyId}/retry`; no body | New `WebhookDispatch` |

`from` and `to` are integer Unix timestamps. A dispatch's `http_status` is
nullable when no HTTP response was received; use `httpStatusCode` to preserve
that distinction. The deprecated `httpStatus` compatibility property maps null
to zero.

Ten consecutive failures pause automatic deliveries (`is_held: true`); scheduled
probes test recovery. Changing the URL or sending `is_active: true` lifts the pause.
Manual `retryDispatch` sends even while paused, and success lifts the pause.
`webhook_id` stays stable across attempts for one event and endpoint; `attempt`
starts at one, `kind` is `scheduled`, `probe`, or `manual`, and `will_retry` indicates
another server attempt. Unknown future kinds are preserved.

New or changed URLs require HTTPS and public DNS resolution. Private, loopback,
link-local and reserved destinations are rejected by the API. Deliveries do not
follow redirects; a 3xx response is a failure. Previously stored HTTP endpoints
remain available for exact-URL lookup and deletion.

### Verifying signed deliveries

Deliveries to an endpoint with `signing_enabled` carry the Standard Webhooks
headers `webhook-id`, `webhook-timestamp` and `webhook-signature`. On the
receiving server, verify the **raw** body:

```swift
let valid = WebhookSignature.verify(
    body: rawBody,
    id: headers["webhook-id"] ?? "",
    timestamp: headers["webhook-timestamp"] ?? "",
    signatureHeader: headers["webhook-signature"] ?? "",
    secret: endpointSecret            // "whsec_…"
)
```

`verify` computes HMAC-SHA256 of `{webhook-id}.{webhook-timestamp}.{body}`
with the base64 key after `whsec_`, accepts any matching space-separated
`v1,<base64>` entry using a constant-time comparison, and rejects timestamps
more than `tolerance` seconds (default `WebhookSignature.defaultTolerance`,
300) from `now`. Objective-C uses
`verifyBody:webhookId:timestamp:signatureHeader:secret:`.

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
- `UpdateNotificationPreferencesPayload`: any nonempty subset of the thirteen
  case-sensitive Boolean notification keys shown above. `nil` values are
  omitted and explicit `false` values are encoded.
- `CreateWorkspacePayload`: required `name`; optional
  `notification_sender_type` (`User` or `Account`).
- `UpdateWorkspacePayload`: optional `name` and `notification_sender_type`.
  Omitted keys remain unchanged.
- `delete(workspaceId:force:)`: always sends `{ "force": boolean }` in the
  `DELETE` body.
- `AccountStatsParams`: optional `granularity` (`monthly` or `daily`) and
  `month` (`YYYY-MM`).

### Signer and document requests

- `CreateSignerPayload`: required `full_name`; optional `email`,
  `whatsapp_phone_number` and `government_id` (four-argument initializer). The SDK rejects a blank name and validates a supplied
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
- `SendTokenPayload`: `{ "channel": "email", "recipient": string }`; both keys
  are required by the API and the recipient must be the signer's email.
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
  `copy_receivers`. `SignerReference.id` encodes only `id`;
  `SignerReference.signer(...)` and descriptor values
  may also encode `verification_method`, `notification_methods`, and positive
  `step`. Creation requires an ID for every signer.
- `AssignmentEntry`: `page_id` and nonempty `fields`. Every field encodes
  `signer_id`, `field_id`, and optional `display_settings`.
- `DisplaySettings`: required finite numeric `left`, `top`, `width`, `height`,
  and `fontSize`; optional `fontFamily`, `backgroundColor`. Left/top must be
  nonnegative and width/height/font size must be positive. The deprecated
  assignment-field initializer accepts a JSON string, decodes it locally to
  this object, and never sends a JSON-encoded string.
- `CreateAssignmentPayload.init(jsonData:)`: decodes the creation JSON shape,
  including descriptor signers and collect entries, for the `payloadJSON`
  Objective-C adapters. Unknown `method` values fail locally. Creation and
  estimation then apply the same validation as typed Swift requests. Malformed
  JSON or incompatible field types throw standard `DecodingError`; the completion
  adapter delivers it as an error on the main queue.
- `CreateAssignmentPayload.withSignerIds(...)`: local convenience constructor
  for virtual assignments using signer IDs. It performs no request itself.
- Assignment estimation derives a narrower body from
  `CreateAssignmentPayload`: signer IDs, steps, message, expiry, and copy
  receivers are removed. Virtual estimates require signers; collect estimates
  require entries.
- Expiration reset always sends `expires_at`; a date sets it and the `expiresAt:`
  overload sends explicit `null` to clear it.
- `TemplateSigner`: required `role_id`; document creation also requires an existing
  signer `id` or `email`. The email initializer accepts optional `name` and
  `whatsapp_phone_number` for a new signer. Other optional values are
  `verification_method`, `notification_methods`, and positive `step`.
  Template cost estimation removes all signer identity fields and steps.
  Use `TemplateSigner(roleId:email:name:whatsappPhoneNumber:verificationMethod:notificationMethods:step:)`
  for email lookup/creation; existing `id:` initializers remain available.
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
  The SDK requires an absolute HTTP or HTTPS URL without user information,
  a valid email, and no blank event names. The API requires HTTPS and a public
  destination for a new or changed URL; stored HTTP URLs remain addressable.
- `CreateWebhookEndpointPayload`: required `url`, `email`, `events`,
  `is_active`, `signing_enabled`; optional `name`. Omitted `events` uses
  `WebhookEventType.defaultEvents`. URL, email and event validation match
  `WebhookRegisterPayload`.
- `UpdateWebhookEndpointPayload`: partial `url`, `email`, `events`, `name`,
  `is_active` and `signing_enabled` (`NSNumber` for the Booleans). At least one
  change is required; set values are validated like creation.
- `VerifyMFAPayload`: required `mfa_token` and `code`.
- `ConfirmTOTPPayload`: required `id` and `code`; optional `password` and
  `reauth_code`.
- `MFAReauthPayload`: optional `password` and `code`; at least one nonblank
  value is required.
- `WebhookDispatchListParams`: positive `page` and `perPage`; optional `event`
  and `endpointId` (`endpoint_id`);
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
- `NotificationPreferences`: the thirteen Boolean keys listed in the authentication
  section. The four `Contract*` keys default to `true` when absent; all other keys
  are required. Swift property names use lower camel case.
- MFA challenge: `{mfa_token: string}` in place of `AuthSession`; surfaced as
  `MFARequiredError.mfaToken`.
- `MFAStatus`: `methods: [MFAMethod]`, `recovery_codes_remaining: integer`.
- `MFAMethod`: `id: string`, `type: string` (`Totp`), `label?: string`,
  `confirmed_at?: date-time`, `last_used_at?: date-time`.
- `TOTPEnrollment`: `id: string`, `secret: string` (base32),
  `provisioning_uri: string` (`otpauth://`).
- `ApiKey`: `api_key?: string`.
- `EmailResponse`: `email: string`.
- `SelfResponse` is the compatibility view containing `user: User` and
  `accounts: [Account]`; the direct v1 user response is exposed by
  `currentUserProfile()`.

### Account and statistics schemas

- `Account`: `resource: string`, `id: string`, `name: string`,
  `primary_color?: string`, `secondary_color?: string`,
  `notification_sender_type: User|Account`, `roles: [string]`,
  `is_delete_allowed: boolean`, `created_at: date-time`,
  `limits?: {webhook_endpoints?: integer}`. `WorkspaceResponse.limits` and
  `WorkspaceListItem.limits` are optional `WorkspaceLimits`;
  `webhookEndpoints: NSNumber?` preserves an omitted limit. Account lists may omit it.
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
  `government_id?: string`, `has_accepted_terms: boolean`.
- `SignerSelf`: all `Signer` fields plus `has_signature: boolean`,
  `has_initial: boolean`, `is_signature_reusable: boolean`, `verification_method?: string`.
- `AcceptTermsResponse` is a source-compatible SDK view with `full_name`,
  `email`, and `has_accepted_terms`; the canonical bare response has no data,
  so the SDK synthesizes empty strings and `true`.
- `AssignmentSigner`: all `Signer` fields plus
  `verification_method?: string`, `notification_methods?: [string]`,
  `identity_verification_status?: string`, `step?: integer`, `notified?: boolean`, `completed?: boolean`, and
  `notification_history?: [NotificationHistoryEntry]`.
- `NotificationHistoryEntry`: `event: string`, `status: sent|failed`,
  `error_code?: string`, `error_message?: string`, `sent_at?: date-time`,
  `failed_at?: date-time`.

### Document schemas

- `Document`: `resource?: string`, `id: string`, `account_id: string`,
  `template_id?: string`, `name: string`, `status: string`,
  `artifacts: DocumentArtifacts`, `is_closed: boolean`,
  `signing_url: string`, `decline_reason?: string`, `declined_by?: Signer`,
  `verification_code?: string`, `verification_url?: string`, `has_contract?: boolean`,
  `tags: [{id: string, name: string}]`, `assignment?: Assignment`,
  `pages: [DocumentPage]`, `created_at: date-time`, `updated_at: date-time`.
  Signer-facing `GET /sign` and `GET /signers/{signerId}/document` can also return
  `current_signer?: Signer`, exposed as `DocumentDetails.currentSigner`.
- `DocumentArtifacts`: URL strings keyed by `original`, `thumbnail?`,
  `certificated?`, `certificate-page?`, `pades?`, and `bundle?`.
- `DocumentPage`: `id: string`, `number: integer`, `height: integer`,
  `width: integer`, `download_url: URL string`.
- `DocumentActivity`: `id: integer`, `event: string`, `message: string`,
  `payload?: object`, `origin?: {ip: string, user-agent: string}`,
  `created_at: date-time`. Swift callers receive lossless `payloadJSON` and
  `originJSON` values. The `payload` and `origin` properties are compatibility
  strings produced by `JSONValue.stringValue`.
- `DocumentVerification`: `hash: string`, `id?: string`,
  `agreement_code?: string` (printed on the document certificate), `status?: string`,
  `page_count?: string`, `signer_count?: string`, `completed_count?: integer`,
  `completed_at?: date-time`, `verified_at: date-time`, `is_valid: boolean`,
  `message: string`. Unknown or invalid hashes return `is_valid: false` with
  the document-specific fields null.
- `DocumentStatus`: `code: string`, `deletable: boolean`.
- `SigningProgress` is SDK-derived, not a wire payload: `signed: integer`,
  `total: integer`, `pending: integer`, `percentage: number`.
- `SendTokenResponse` decodes the response `data`:
  `document: PublicDocumentInfo` (`id`, `name`, `pageCount`, `createdBy`),
  `channel: string`, `recipient: string`.

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
`pageCount` are optional and may be absent. All four views expose optional
`verificationCode`, `verificationURL`, and `hasContract: NSNumber?`; missing or
null contract state remains unknown rather than becoming false.

### Assignment and cost schemas

- `Assignment`: `resource: string`, `id: string`, `sender_email: string`,
  `document_id?: string`, `created_at?: date-time`,
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
- `WhatsappNotification`: `sent_at: date-time`, `header: string`, `body: string`,
  `buttons: [{text: string}]`, `phone_number: string`, `signer_id: string`.
  `sentAtString: String?` retains the ISO-8601 value; the compatibility `sentAt: Int`
  derives Unix seconds, or zero when absent. Legacy numeric timestamps also decode.
- `CostEstimate`: `documents: integer`, `credits: number`,
  `needs_extra_document: boolean`, `extra_document_cost: number`,
  `total_credits: number`, `breakdown: [CostEstimateBreakdownItem]`,
  `document_balance: number`, `credit_balance: number`,
  `has_sufficient_resources: boolean`,
  `blocking_reason?: PendingPayment|InsufficientDocuments|InsufficientCredits`,
  `message?: string`.
- Reminder estimates use `total: number`, `breakdown: [{code, name, cost}]`,
  `credit_balance: number|null`, and `has_sufficient_credits: boolean`.
  `estimateResendCost` returns `CostEstimate`: `totalCredits` reads `total`, and
  `hasSufficientResources` / `hasSufficientBalance` read `has_sufficient_credits`.
  A null balance means unlimited credits and remains `NSNull` in `raw`; the numeric
  compatibility `creditBalance` is zero. Use the sufficiency flag for decisions.
- `CostEstimateBreakdownItem`: `code: string`, `name: string`, `cost: number`,
  `quantity: integer`, `unit_cost: number`; reminder estimates omit the last two,
  whose compatibility properties default to zero.

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
  `is_held: boolean`, `held_since?: integer` Unix seconds,
  `url?: URL string`, `email?: string`, `updated_at?: date-time`. The SDK also
  tolerates extension/legacy `id` and `created_at` fields.
- `WebhookEndpoint`: `id: string`, `name?: string`, `url: string`,
  `email: string`, `events: [string]`, `is_active: boolean`,
  `signing_enabled: boolean`, `is_held: boolean`, `held_since?: integer` Unix seconds,
  `created_at: date-time`, `updated_at: date-time`;
  `secret?: string` is returned once when creation or update generates a secret.
  Both endpoint and subscription expose `isHeld: Bool` (false if absent) and
  `heldSince: NSNumber?` (nil if missing or null).
- `WebhookEventType`: `id: string`, `description: string`.
- `WebhookDispatch`: `resource: string`, `id: string`, `event: string`,
  `activity_id: integer`, `endpoint?: URL string`, `endpoint_id?: string`,
  `webhook_id?: string`, `attempt?: integer`, `kind?: string`, `will_retry: boolean`,
  `payload?: object`,
  `delivered: boolean`, `http_status?: integer`, `response_body?: string`,
  `error?: string`, `created_at: date-time`, `updated_at: date-time`.
  `payloadJSON` is the lossless Swift value; `payload` is a Foundation
  dictionary compatibility view. `httpStatusCode` preserves a missing/null
  status; deprecated `httpStatus` maps it to zero. `webhookId: String?`,
  `attempt: NSNumber?`, `kind: String?`, and `willRetry: Bool` expose retry metadata;
  omitted `will_retry` defaults false.

The contract event constants on `WebhookEventType` are:

| Swift constant | Wire event |
| --- | --- |
| `documentContractUpdated` | `document_contract_updated` |
| `documentContractRenewalNotice` | `document_contract_renewal_notice` |
| `documentContractExpiring` | `document_contract_expiring` |
| `documentContractExpired` | `document_contract_expired` |
| `documentContractRenewed` | `document_contract_renewed` |
| `documentContractTerminated` | `document_contract_terminated` |
| `documentContractAmended` | `document_contract_amended` |
| `documentContractAmendmentUpdated` | `document_contract_amendment_updated` |

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
- `SignerVerificationMethod` encodes `.email`, `.whatsapp`, and
  `.digitalCertificate` as `Email`, `Whatsapp`, and `DigitalCertificate`.
  Biometric assignments use the raw-string `IdDocumentFaceMatchBasic` forms.
  `SignerNotificationMethod` encodes `.email` and `.whatsapp` the same way.
  `SignerReference.signer(id:verification:notifications:step:)` and
  `TemplateSigner(roleId:id:verification:notifications:step:)` take these
  typed values; the raw-`String` forms remain for values added to the API after
  an SDK release. Reading a signer back, `Signer.verification` and
  `Signer.notifications` return the typed values and drop anything unknown
  rather than failing to decode.
  - `Email` is the default and is free.
  - `Whatsapp` bills 0.45 credits for the required notification channel and is
    available on paid subscriptions only.
  - `DigitalCertificate` has the signer sign with their own ICP-Brasil
    certificate — **A1** (a software file) or **A3** (a smart card or USB
    token), both presented through the Web PKI browser extension, producing a
    qualified PAdES signature. It requires the Digital Certificate feature, a
    CPF or CNPJ in the signer's `government_id`, and that the signer be alone
    in their step. The assignment must be `virtual`; it bills 0.5 credits plus
    its notification. A CPF requires that person's certificate
    (an e-CPF, or an e-CNPJ naming them as legal representative); a CNPJ
    requires an e-CNPJ for that company. The signing handshake itself happens
    in the browser and is not wrapped by this SDK.
- `DocumentArtifactName` path values are `original`, `certificated`,
  `certificate-page`, `pades`, and `bundle`.
- `SignatureType` path/query values are `signature` and `initial`.
- `SendTokenChannel.email` encodes `email`, the only channel `send-token`
  accepts; the deprecated `.whatsapp` is rejected before I/O.
- `NotificationSenderType.user` and `.account` encode `User` and `Account`.
- `DocumentStatus` maps `uploading`, `uploaded`, `metadata_processing`,
  `metadata_ready`, `pending_signature`, `expired`, `certificating`,
  `certificated`, `rejected_by_signer`, `rejected_by_user`, and `failed`.
  Unknown strings decode to `.unknown`; `stringValue` performs the reverse
  mapping. `pending_identity_review` remains available in document `statusString` and maps
  to `.unknown` in the existing enum; readiness polling recognizes the raw status.
- `WebhookEventType` provides constants for `document_uploaded`,
  `document_metadata_ready`, `document_prepared`, `assignment_created`,
  `document_ready`, `signature_requested`, `signer_created`,
  `signer_email_verified`, `signer_whatsapp_verified`,
  `signer_data_confirmed`, `signer_viewed_document`,
  `signer_signed_document`, `signer_rejected_document`,
  `user_rejected_document`, `document_processing_failed`, `template_created`,
  `template_processed`, `template_processing_failed`, `signer_identity_verified`,
  `signer_identity_verification_failed`, `signer_identity_review_required`,
  `signer_identity_review_approved`, and `signer_identity_review_rejected`. `defaultEvents`
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
session with cookies and URL caching disabled that requires TLS 1.2 or newer.
It never retries a request. Its initializer validates an
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

`POST /oauth/token` and `POST /oauth/revoke` bypass this policy and refuse
every redirect, because their body carries a code or token: the `3xx` itself
becomes the response and is thrown as `APIError`.

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
| `APIError` | Non-2xx HTTP, or a response envelope whose `status` is outside 200...299 | `statusCode`, `message`, raw `responseData`, `context`, `workspaceDeletionRestrictions`, `oauthError`, `insufficientScope`, `rateLimitLimit`, `rateLimitRemaining`, `rateLimitReset`, `retryAfter` (from `X-Rate-Limit-Limit`, `X-Rate-Limit-Remaining`, `X-Rate-Limit-Reset`, and `Retry-After` on `429`) | Domain `ASFErrorDomain.api`; code is HTTP status; `userInfo["responseData"]`, the raw `WWW-Authenticate` challenge as `userInfo["wwwAuthenticate"]`, the scope a `403` `insufficient_scope` challenge names as `userInfo["insufficientScope"]`, and integer `rateLimitLimit`, `rateLimitRemaining`, `rateLimitReset`, `retryAfter`, each when present. |
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

A malformed envelope cannot fall through to flat-object decoding.
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
| Assignment | `listAssignmentsWithAccountId:completion:`, `createAssignmentForDocument:signerIds:completion:`, `resendNotificationForDocument:assignmentId:signerId:completion:`, `resetExpirationWithDocumentId:assignmentId:expiresAt:completion:`, `resetExpirationWithDocumentId:assignmentId:newExpiresAt:completion:`, `estimateResendCostWithDocumentId:assignmentId:signerId:completion:`, `signWithDocumentId:assignmentId:signerAccessCode:fields:completion:`, `declineWithDocumentId:assignmentId:signerAccessCode:reason:completion:`, `listWhatsappNotificationsWithDocumentId:assignmentId:completion:`, `createAssignmentForDocument:payloadJSON:completion:`, `estimateAssignmentCostForDocument:payloadJSON:completion:`, `listWithQuery:accountId:completion:` |
| Auth | `loginWithPayload:completion:`, `getAPIKeyWithCompletion:`, `createAPIKeyWithPayload:completion:`, `currentUserWithCompletion:`, `getNotificationPreferencesWithCompletion:`, `updateNotificationPreferences:completion:`, `statsWithParams:completion:`, `linkSocialLogin:completion:`, `socialLoginWithPayload:completion:`, `currentUserProfileWithCompletion:`, `changePasswordWithPayload:completion:`, `changePasswordAndReturnResponseWithPayload:completion:`, `requestPasswordResetWithPayload:completion:`, `requestPasswordResetAndReturnResponseWithPayload:completion:`, `resetPasswordWithPayload:completion:`, `resetPasswordAndReturnResponseWithPayload:completion:`, `deleteAPIKeyWithCompletion:`, `verifyMFAWithPayload:completion:`, `mfaStatusWithCompletion:`, `enrollTOTPWithLabel:completion:`, `confirmTOTPWithPayload:completion:`, `regenerateRecoveryCodesWithProof:completion:`, `removeMFAMethodWithId:proof:completion:` |
| Document | `uploadDocument:accountId:completion:`, `listDocumentsWithAccountId:completion:`, `getDocumentWithId:completion:`, `deleteDocumentWithId:completion:`, `renameDocumentWithId:name:completion:`, `searchDocumentsWithTerm:status:accountId:completion:`, `uploadWithData:options:completion:`, `listWithDocumentListParams:accountId:completion:`, `searchWithSearch:status:page:perPage:accountId:completion:`, `searchWithSearch:status:sort:page:perPage:accountId:completion:`, `waitUntilReadyWithDocumentId:options:completion:`, `downloadArtifactWithDocumentId:artifact:completion:`, `downloadThumbnailWithDocumentId:completion:`, `downloadPageWithDocumentId:pageId:completion:`, `activitiesWithDocumentId:completion:`, `activitiesWithDocumentId:query:completion:`, `createFromTemplateWithTemplateId:signers:options:accountId:completion:`, `estimateCostFromTemplateWithTemplateId:signers:accountId:completion:`, `verifyWithSignatureHash:completion:`, `verifyDetailsWithSignatureHash:completion:`, `isFullySignedWithDocumentId:completion:`, `getSigningProgressWithDocumentId:completion:`, `listStatusesWithCompletion:`, `getPublicInfoWithDocumentId:completion:`, `sendPublicSignTokenWithDocumentId:payload:completion:`, `sendPublicSignTokenWithDocumentId:email:completion:`, `confirmSignerDataWithDocumentId:signerAccessCode:payload:completion:`, `confirmSignerDataAndReturnSignerWithDocumentId:signerAccessCode:payload:completion:`, `listWithQuery:accountId:completion:` |
| Field | `createField:accountId:completion:`, `listFieldsWithAccountId:completion:`, `getFieldWithId:accountId:completion:`, `deleteFieldWithId:accountId:completion:`, `listWithFieldListParams:accountId:completion:`, `updateWithFieldId:payload:accountId:completion:`, `validateWithFieldId:value:signerAccessCode:accountId:completion:`, `validateMultipleWithItems:signerAccessCode:accountId:completion:`, `listFieldTypesWithCompletion:` |
| OAuth | `protectedResourceMetadataWithCompletion:`, `authorizationServerMetadataWithIssuer:completion:`, `exchangeAuthorizationCode:completion:`, `refreshAccessToken:completion:`, `revokeToken:completion:`, `userInfoWithCompletion:` |
| Signer | `createSigner:accountId:completion:`, `getSignerWithId:accountId:completion:`, `updateSignerWithId:payload:accountId:completion:`, `deleteSignerWithId:accountId:completion:`, `findSignerByEmail:accountId:completion:`, `getSelfWithSignerAccessCode:completion:`, `acceptTermsWithSignerAccessCode:completion:`, `acceptTermsWithoutResponseWithSignerAccessCode:completion:`, `verifyEmailWithPayload:completion:`, `uploadSignatureWithSignerAccessCode:type:imageData:reuse:completion:`, `uploadSignatureWithSignerAccessCode:type:imageData:reusePreference:completion:`, `downloadSignatureWithSignerAccessCode:type:completion:`, `getCurrentDocumentWithSignerId:signerAccessCode:completion:`, `listSignerDocumentsWithSignerId:signerAccessCode:params:completion:`, `searchSignerDocumentsWithSignerId:signerAccessCode:search:status:completion:`, `signMultipleDocumentsWithSignerAccessCode:documentIds:completion:`, `declineMultipleDocumentsWithSignerAccessCode:documentIds:reason:completion:`, `downloadSignerDocumentArtifactWithSignerId:documentId:artifact:completion:`, `downloadSignerDocumentArtifactWithSignerId:documentId:artifact:signerAccessCode:completion:`, `getSigningDocumentWithSignerAccessCode:hasAcceptedTerms:completion:`, `listDocumentsAsWorkspaceWithSignerId:params:completion:`, `searchDocumentsAsWorkspaceWithSignerId:search:completion:`, `listWithQuery:accountId:completion:` |
| Tag | `listTagsWithAccountId:completion:`, `createTag:accountId:completion:`, `updateTagWithId:payload:accountId:completion:`, `deleteTagWithId:force:accountId:completion:`, `listWithTagListParams:accountId:completion:`, `deleteAndReturnStatusWithTagId:force:accountId:completion:`, `listDocumentTagsWithDocumentId:accountId:completion:`, `replaceDocumentTagsWithDocumentId:tagIds:accountId:completion:`, `appendDocumentTagsWithDocumentId:tagIds:accountId:completion:`, `detachDocumentTagWithDocumentId:tagId:accountId:completion:`, `detachDocumentTagAndReturnStatusWithDocumentId:tagId:accountId:completion:` |
| Template | `listTemplatesWithAccountId:completion:`, `getTemplateWithId:accountId:completion:`, `deleteTemplateWithId:accountId:completion:`, `createWithName:pdfData:accountId:completion:`, `updateWithTemplateId:payload:accountId:completion:`, `listWithTemplateListParams:accountId:completion:`, `listWithQuery:accountId:completion:` |
| Webhook | `registerWebhook:accountId:completion:`, `getWebhookWithAccountId:completion:`, `deleteWebhookWithAccountId:completion:`, `inactivateWebhookWithAccountId:completion:`, `inactivateWebhookAndReturnWithAccountId:completion:`, `listDispatchesWithAccountId:completion:`, `listEventTypesWithCompletion:`, `listDispatchesWithWebhookDispatchListParams:accountId:completion:`, `retryDispatchWithDispatchId:accountId:completion:`, `listWebhookEndpointsWithAccountId:completion:`, `createWebhookEndpoint:accountId:completion:`, `getWebhookEndpointWithId:accountId:completion:`, `updateWebhookEndpointWithId:payload:accountId:completion:`, `deleteWebhookEndpointWithId:accountId:completion:`, `webhookSigningSecretWithEndpointId:accountId:completion:`, `rotateWebhookSigningSecretWithEndpointId:accountId:completion:` |
| Workspace | `createWorkspace:completion:`, `listWorkspacesWithCompletion:`, `getWorkspaceWithId:completion:`, `updateWorkspaceWithId:payload:completion:`, `deleteWorkspaceWithId:force:completion:`, `themeWithAccountId:completion:`, `statsWithParams:accountId:completion:`, `downloadLogoWithAccountId:completion:`, `uploadLogo:filename:contentType:accountId:completion:`, `deleteLogoWithAccountId:completion:`, `listWithQuery:completion:` |

`ListParams` completion overloads remain Swift-only; Objective-C uses the
`query:` dictionary overload, with exact wire names such as `per-page`.
`CreateAssignmentPayload` completion overloads remain Swift-only; Objective-C
uses `payloadJSON:` (`NSData`) with the creation JSON shape. Boolean results
are nullable `NSNumber` values; nil means failure. `getSigningDocument` accepts
nullable `NSNumber` for the optional terms flag. JSON-preserving field overloads
remain Swift-only, with the string value API available to Objective-C.
The high-level client exposes
`uploadAndRequestSignaturesWithDocumentData:options:accountId:completion:`,
returning separate document and assignment arguments on the main queue.

The explicitly named non-resource initializers are
`initWithAPIKey:token:baseURL:defaultAccountId:timeout:` on configuration,
`initWithType:name:regex:isRequired:isActive:clearsRegex:` on
`UpdateFieldPayload`,
`initWithFullName:email:whatsappPhoneNumber:governmentId:` on
`UpdateSignerPayload`, `initWithPage:perPage:` on
`SignerDocumentListParams`, and
`initWithStatus:search:tagIds:sort:page:perPage:` on `TemplateListParams`.
`TemplateSigner` provides
`initWithRoleId:email:name:whatsappPhoneNumber:verificationMethod:notificationMethods:step:`
for email lookup/creation. `reusePreference:` on signature upload uses nullable
`NSNumber`; false explicitly disables reuse, true enables it, and nil preserves it.

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

Resource mutation tests require `ASSINAFY_RUN_LIVE_MUTATIONS=1`. Invitation
and disposable-workspace tests also require two distinct recipients:

```sh
ASSINAFY_RUN_LIVE_MUTATIONS=1 \
ASSINAFY_TEST_EMAIL_A="recipient-a@example.invalid" \
ASSINAFY_TEST_EMAIL_B="recipient-b@example.invalid"
```

Use two distinct controlled recipients. Never commit credentials, account IDs,
signer access codes, personal addresses, or captured API payloads.


## Identity document and face verification

Select the raw `verificationMethod: "IdDocumentFaceMatchBasic"` on
`SignerReference.descriptor` or `TemplateSigner`. The account needs the ID Document + Face Match
feature and each signer needs a valid CPF in `government_id`. Set it with
`CreateSignerPayload(fullName:email:whatsappPhoneNumber:governmentId:)`; the original
initializer omits it. `create` reuses an email match without updating it, so call
`signers.update` with `UpdateSignerPayload(..., governmentId:)` for an existing signer.
Email or WhatsApp may notify a biometric signer; exactly one channel is allowed.
Estimate the per-signer fee before assignment creation. It is charged once per signer,
including when an expired capture session is restarted.

These operations use the normal `{status,message,data}` envelope. Signer requests carry
only `signer-access-code`; workspace requests carry the configured credential.
[Complete requests and responses](PAYLOADS.md#startidentityverificationpayload) include
all evidence fields. These routes are deployed on production; sandbox currently returns 404.

| Async SDK method | Auth | Exact request | Response |
| --- | --- | --- | --- |
| `signers.identityVerification(signerAccessCode:)` | Signer | `GET /signers/identity-verification?signer-access-code={code}`; no body | `IdentityVerificationState`: `can_start: Bool`, nullable `status`, `url`, `expires_at`, `completed_at` |
| `signers.startIdentityVerification(signerAccessCode:payload:)` | Signer | `POST` to the same path/query; JSON `{ "consent": true }` | `IdentityVerificationSession`: `id`, `url`, nullable `expires_at` |
| `assignments.identityReview(documentId:assignmentId:signerId:)` | Account | `GET /documents/{documentId}/assignments/{assignmentId}/signers/{signerId}/identity-verification`; no body | `SignerIdentityReview` |
| `assignments.downloadIdentityReviewImage(documentId:assignmentId:signerId:name:)` | Account | Same path plus `/images/{name}`; no body | Raw JPEG, PNG or PDF `Data`, available only while `InReview` |
| `assignments.reviewIdentityVerification(documentId:assignmentId:signerId:payload:)` | Account | `POST` to the review path plus `/review`; JSON `{ "decision": "Approved" \| "Rejected", "note": string? }` | Updated `SignerIdentityReview` |

OAuth applications with `documents:read` may read the review summary. Image access
and review decisions return `403` for OAuth tokens regardless of scope; a workspace
reviewer performs these actions in Assinafy.

`StartIdentityVerificationPayload(consent:)` requires explicit true before I/O.
`ReviewIdentityVerificationPayload(decision:note:)` requires exactly `Approved` or
`Rejected` and at most 2,000 Unicode scalar values in its optional note. A nil note is
omitted. Invalid image names, path IDs and blank access codes fail before I/O.

`IdentityVerificationState.canStart` is true before the first session or after `Expired`.
Other statuses are `Pending`, `InReview`, `Approved`, `Declined` and `Abandoned`.
A declined or abandoned verification requires a new document and assignment. Open a
capture `url` unchanged, including its `#t=` fragment. It is a bearer link: never log it
or persist it in browser storage. `expires_at` limits capture, not later processing.

`InReview` allows viewing, confirming signer data and signing. Once all signers finish,
the `pending_identity_review` status holds certification until every open review is
approved. Rejection cancels the document as `rejected_by_user` and notifies signers and
copy recipients. Notes are recorded for the workspace/provider, never shown to signers.

`SignerIdentityReview` contains `id`, `status`, `provider`, `verificationMethod`,
`reasonCodes`, `evidenceAvailable`, nullable `expected`, `document`, `matches`,
`rulesetVersion`, `evidenceSHA256`, `reviewedBy`, `reviewedAt`, `reviewNote`, `completedAt`,
and arrays `checks` and `images`. Wire keys are snake_case. Missing arrays become empty;
missing evidence remains nil and `evidenceAvailable` defaults false.

| Nested model | Wire fields and SDK mapping |
| --- | --- |
| `IdentityReviewReason` | `code`, `description` -> `reasonDescription`; unknown reasons retain the code |
| `IdentityReviewPerson` | Nullable `name`, `cpf`; `type` is present only for the document read |
| `IdentityReviewMatches` | Nullable `cpf` and `birth_date` Booleans, `name` similarity (0–1); all use `NSNumber?` for Objective-C |
| `IdentityReviewCheck` | `name`, `result`, nullable numeric `score` (`NSNumber?`), `reasons: [String]` |
| `IdentityReviewUser` | Reviewer `id`, `name` |

The valid image names are `document_front`, `document_back`, `document_pdf`, and `face`.
The provider supplies images transiently; they disappear after the decision. Do not
persist sensitive evidence. `Signer.identityVerificationStatus` and
`SignerSelfInfo.verificationMethod` expose the assignment's current verification state.

All five operations provide explicit main-queue Objective-C forms:
`identityVerificationWithSignerAccessCode:completion:`,
`startIdentityVerificationWithSignerAccessCode:payload:completion:`,
`identityReviewWithDocumentId:assignmentId:signerId:completion:`,
`downloadIdentityReviewImageWithDocumentId:assignmentId:signerId:name:completion:`, and
`reviewIdentityVerificationWithDocumentId:assignmentId:signerId:payload:completion:`.

## Webhooks by URL and creation secrets

| Async SDK method | Auth | Request | Response |
| --- | --- | --- | --- |
| `webhooks.listEndpoints(url:accountId:)` | Account | `GET /accounts/{accountId}/webhooks/endpoints?url={exactURL}`; no body | `[WebhookEndpoint]` with exact URL matches; the SDK also filters locally because sandbox ignores this query |
| `webhooks.deleteEndpoint(url:accountId:)` | Account | `DELETE` at the same path/query; no body | Success envelope with `data: []`, returned as `Void`; 404 when absent |

The original no-filter listing and ID deletion remain available. Exact URL forms require
an absolute HTTP(S) URL without user information and preserve query/trailing-slash values.
Their main-queue selectors are `listWebhookEndpointsWithURL:accountId:completion:` and
`deleteWebhookEndpointWithURL:accountId:completion:`.

`createEndpoint` returns `WebhookEndpoint.secret` once when signing is enabled;
`updateEndpoint` also returns a newly generated secret when enabling signing.
Save it securely on the receiving server. List/view responses omit it. OAuth applications
cannot read an existing secret, but may call `rotateSigningSecret` with `webhooks:write`.
Rotation invalidates the previous secret immediately. API-key callers may also use
`signingSecret` to read it.

Subscribe to biometric events with `WebhookEventType.signerIdentityVerified`,
`signerIdentityVerificationFailed`, `signerIdentityReviewRequired`,
`signerIdentityReviewApproved`, and `signerIdentityReviewRejected`. The default event list
is unchanged. Verify the raw body before processing and deduplicate using `webhook-id`;
a valid signature can be delivered more than once inside the timestamp tolerance.

## Contract management

`client.contracts` manages contract terms on existing workspace documents. Upload
the document first, then set its terms; uploading and tracking are separate
operations. Contract tracking does not change the document's signing method,
signers, or notification configuration.

All six operations use **Account auth**. An OAuth application needs
`documents:read` for reads and `documents:write` for writes. Writes also require
an active workspace member and a plan with contract tracking. Existing terms
remain readable when that plan feature is unavailable. `accountId` defaults to
`nil`, resolving through the client's `defaultAccountId`; document and workspace
IDs are validated before I/O.

### Operations

| Swift method | Auth | HTTP request | Response |
| --- | --- | --- | --- |
| `list(params:accountId:)` | Account; OAuth `documents:read` | `GET /accounts/{accountId}/contracts`; the filters below, no body | Envelope `data: [DocumentContract]` → `PaginatedResult<DocumentContract>` with pagination headers |
| `get(documentId:accountId:)` | Account; OAuth `documents:read` | `GET /accounts/{accountId}/documents/{documentId}/contract`; no body | Envelope `data: DocumentContract \| DocumentContractAmendment` → `ContractDetails` |
| `update(documentId:payload:accountId:)` | Account; OAuth `documents:write` | `PUT /accounts/{accountId}/documents/{documentId}/contract`; `UpdateContractPayload` JSON | Saved root terms or amendment link → `ContractDetails` |
| `related(documentId:accountId:)` | Account; OAuth `documents:read` | `GET /accounts/{accountId}/documents/{documentId}/contract/related`; no body | Root `DocumentContract` with its amendment family, whether called on the root or an instrument |
| `renew(documentId:payload:accountId:)` | Account; OAuth `documents:write` | `POST /accounts/{accountId}/documents/{documentId}/contract/renew`; `RenewContractPayload` JSON | Renewed `DocumentContract` |
| `terminate(documentId:payload:accountId:)` | Account; OAuth `documents:write` | `POST /accounts/{accountId}/documents/{documentId}/contract/terminate`; `TerminateContractPayload` JSON, `{}` by default | Terminated `DocumentContract` |

Complete [contract request and response examples](PAYLOADS.md#contract-management)
include root terms, pending/applied instruments, renewal, termination, and errors.
Every successful response follows the standard `{status, message, data}` envelope.

### Listing and synchronization

`ContractListParams()` starts with every property `nil`. Set only the filters
needed; all supplied filters narrow the result. `list` defaults to a new empty
params object. Keep mutable params unchanged while a request is running.

| Property | Swift / Objective-C type | Query key and meaning |
| --- | --- | --- |
| `status` | `String?` / `NSString *` | `status`; comma-separated `draft`, `active`, `expired`, `terminated`; matches any listed status |
| `counterparty` | `String?` | `counterparty`; part of a counterparty name or its exact CPF/CNPJ |
| `search` | `String?` | `search`; part of the document name |
| `endDateFrom` | `String?` | `end_date_from`; inclusive earliest end date, `YYYY-MM-DD` |
| `endDateTo` | `String?` | `end_date_to`; inclusive latest end date, `YYYY-MM-DD` |
| `endingWithinDays` | `NSNumber?` | `ending_within_days`; integer 0–3650, inclusive from today in Brasília time; 0 means today |
| `externalSystem` | `String?` | `external_system`; external reference system |
| `externalId` | `String?` | `external_id`; external reference identifier |
| `sort` | `String?` | `sort`; `end_date` or `updated_at`, with optional leading `-`; server default `-updated_at`; missing end dates sort last in either direction |
| `expand` | `String?` | `expand=document`; includes each contract's document |
| `page` | `NSNumber?` | `page`; integer starting at 1 |
| `perPage` | `NSNumber?` | `per-page`; integer 1–100 |

Every terms change, including a lifecycle change, moves `updated_at`. To recover
missed webhooks, page the default newest-first list until the records are older
than the application's last synchronization point. Document activity history is
available through `client.documents.activities(documentId:params:)`. The list has
no `updated_since` filter. `PaginatedResult.meta` uses the normal
`X-Pagination-*` headers; completion callers receive the items array.

### Updating root terms and amendment links

`UpdateContractPayload` has an initializer containing every property below.
All value parameters default to `nil`; `clearFields` defaults to `[]`.
The payload is immutable and encodes only supplied fields. At least one field
must be supplied. All 16 API fields are represented; `clearFields` is an SDK
encoding control and is never sent as a JSON key.

| Initializer argument / property | Type | JSON key | Meaning and API constraints |
| --- | --- | --- | --- |
| `status` | `String?` | `status` | `draft`, `active`, `expired`, or `terminated` on creation. An initial expired contract needs a past end date; an initially terminated contract needs an end date. On existing terms only permitted `draft`/`active` transitions are accepted; active never returns to draft. Null is forbidden. |
| `counterpartyName` | `String?` | `counterparty_name` | Up to 255 characters, no HTML; emoji are retained and other four-byte characters are removed by the API. |
| `counterpartyTaxpayerId` | `String?` | `counterparty_taxpayer_id` | Valid CPF/CNPJ, formatted or unformatted; returned as digits. |
| `value` | `NSDecimalNumber?` | `value` | 0 through 9999999999999.99, at most two decimal places. Encoded through Foundation `Decimal`, without converting through `Double`. |
| `currency` | `String?` | `currency` | Three letters, stored uppercase; defaults to `BRL` when a value is set without a currency. |
| `startDate` | `String?` | `start_date` | `YYYY-MM-DD`, year 1000 or later. |
| `endDate` | `String?` | `end_date` | `YYYY-MM-DD`, on or after the start date. Changing it starts a new term. |
| `autoRenew` | `NSNumber?` | `auto_renew` | Optional boolean; use `NSNumber(value: true)` or `NSNumber(value: false)`. |
| `renewalTermMonths` | `NSNumber?` | `renewal_term_months` | Integer 1–600; the API uses 12 months when unset. |
| `noticePeriodDays` | `NSNumber?` | `notice_period_days` | Integer 0–3650; no notice period when unset. |
| `ownerId` | `String?` | `owner_id` | An active workspace member. |
| `metadata` | `[String: String]?` | `metadata` | Replaces the metadata object. Up to 50 keys of 1–40 letters, digits, `_`, `-`, or `.`, each containing plain text of at most 500 characters. Numeric values under keys ending in `_at`, or under `stuck_since`, are not accepted; this SDK's metadata values are strings. |
| `externalReferences` | `[ContractExternalReference]?` | `external_references` | Replaces the entire list; up to 20 items. `[]` clears it. |
| `parentDocumentId` | `String?` | `parent_document_id` | Links this document to a contract document or any document in its family, resolved to the root. |
| `relationType` | `String?` | `relation_type` | `amendment`, `renewal`, or `termination`; required on the first link. Null is not supported. |
| `updatedAt` | `String?` | `updated_at` | Last-read root or link timestamp. A mismatch returns `409 ContractChanged` without writing. Omission or null means last write wins. |
| `clearFields` | `[String]` | Not sent | Nullable wire keys to encode as explicit JSON null; unknown keys, `status`, `relation_type`, and fields simultaneously set to a value are rejected locally. |

`ContractExternalReference(system:id:)` supplies two required strings.
`system` accepts letters, digits, `_`, `-`, and `.`, up to 64 characters, and is
stored lowercase. `id` is preserved, up to 255 characters, without emoji or
other four-byte characters. The API keeps the first of references equal ignoring
case; other database-equivalent duplicates, such as accent variants, return `400`.

The following wire names may appear in `clearFields`:
`counterparty_name`, `counterparty_taxpayer_id`, `value`, `currency`, `start_date`,
`end_date`, `auto_renew`, `renewal_term_months`, `notice_period_days`, `owner_id`,
`metadata`, `external_references`, `parent_document_id`, and `updated_at`.

For root terms, null clears the value; null `auto_renew` resets to false, and null
`currency` resets to `BRL` while a monetary value remains set. Nil Swift values
alone leave fields unchanged. For a pending amendment, null drops a field from
its delta; it does not clear that field on the parent. Explicit
`parent_document_id: null` unlinks a pending instrument. Applied instruments
cannot be edited or unlinked.

A document carries either its own terms or an amendment link. A new link cannot
be attached to a document already carrying root terms. Cancelled, declined, or
expired documents accept neither new terms nor a first link; existing terms or
links remain editable under their usual rules.

| Relation | Allowed delta |
| --- | --- |
| `amendment` | `value`, `currency`, `start_date`, `end_date`, `auto_renew`, `renewal_term_months`, `notice_period_days`, `counterparty_name`, `counterparty_taxpayer_id`, `metadata` |
| `renewal` | `end_date`, `value` |
| `termination` | `end_date`, the effective date; with no date the signing day applies |

An amendment's `start_date` is its displayed effective-from date. Linking merges
the supplied terms into a pending delta. The parent changes once the instrument
is certificated, immediately if already certificated. Instruments apply in the
order their certifications were recorded; an earlier instrument that cannot
apply holds later ones back. A certificated document without a recorded
certification waits for the hourly run to place it by certification time. An
instrument signed before one already applied remains blocked, rather than
overwriting the later terms; its `apply_error` explains the condition. Applied
instruments retain their change record and currency.

### Renewal, termination, and concurrency

`RenewContractPayload(term:endDate:value:clearsValue:updatedAt:)` defaults every
optional value to `nil` and `clearsValue` to `false`.

| Argument / property | Type | JSON key | Behavior |
| --- | --- | --- | --- |
| `term` | `NSNumber?` | `term` | Current term, integer at least 1. Required unless a nonblank explicit end date is supplied. |
| `endDate` | `String?` | `end_date` | Explicit new date after the current end date. Nil or empty uses the configured renewal interval and requires `term`; the API steps that interval until the date is in the future. |
| `value` | `NSDecimalNumber?` | `value` | New exact decimal amount; omitted when nil. |
| `clearsValue` | `Bool` | Controls `value` | True sends `value: null`; cannot be combined with a non-nil value. |
| `updatedAt` | `String?` | `updated_at` | Optional last-read root timestamp. |

Renewal increments `term`, reopens an expired contract, and restarts lifecycle
alerts for the new term. A terminated contract cannot be renewed. Repeating the
same renewal is refused once the contract has advanced: `TermMismatch`,
`EndDateNotAfterCurrent`, or `409` for a stale timestamp. The SDK never retries.

`TerminateContractPayload(reason:updatedAt:)` defaults both strings to `nil`.
`reason` is retained in the termination event, limited to 500 characters, with
HTML stripped by the API. `updatedAt` is the optional concurrency precondition.
The resource method's default payload sends `{}`. Termination changes contract
status to `terminated` and stops lifecycle alerts; it does not cancel the signed
document. Repeating termination returns `400 AlreadyTerminated`.

For all three writes, send the `updatedAt` returned by the read of the record
being changed. For an instrument use its link's timestamp, not its parent's.
Timestamps are checked to the second; fractional seconds are ignored. A new
contract or first link has no prior timestamp, so omit it. On `409`, read again,
decide whether the intended change still applies, and issue a new write using
the new timestamp. The SDK does not merge or retry a conflict.

The SDK rejects empty updates, invalid/null-conflicting clear fields, noninteger
or out-of-range numeric filters/intervals, missing renewal guards, nonfinite
decimal amounts, and termination reasons longer than 500 characters before I/O.
The API enforces date validity, permitted lifecycle transitions, tax IDs,
membership, plan entitlement, monetary bounds/scale, metadata, and link rules.

### Response models

`ContractDetails` represents the GET/PUT response union without requiring an
Objective-C caller to inspect JSON. Exactly one of `contract: DocumentContract?`
and `amendment: DocumentContractAmendment?` is populated. The discriminator
`resource: "document_contract_amendment"`, or a non-null `parent_document_id`,
selects the amendment branch.

| `DocumentContract` property | Type | Wire field |
| --- | --- | --- |
| `resource` | `String?` | `resource` |
| `documentId` | `String?` | `document_id` |
| `status` | `String?` | `status`; unknown future strings are preserved |
| `counterpartyName` | `String?` | `counterparty_name` |
| `counterpartyTaxpayerId` | `String?` | `counterparty_taxpayer_id` |
| `value` | `NSDecimalNumber?` | `value`; decoded directly through `Decimal` |
| `currency` | `String?` | `currency` |
| `startDate` | `String?` | `start_date` |
| `endDate` | `String?` | `end_date` |
| `autoRenew` | `Bool` | `auto_renew`; false when absent or null |
| `renewalTermMonths` | `NSNumber?` | `renewal_term_months` |
| `noticePeriodDays` | `NSNumber?` | `notice_period_days` |
| `term` | `NSNumber?` | `term` |
| `ownerId` | `String?` | `owner_id` |
| `metadata` | `[String: String]?` | `metadata` |
| `externalReferences` | `[ContractExternalReference]` | `external_references`; empty when absent or null |
| `document` | `DocumentDetails?` | `document`, with `expand=document` |
| `amendments` | `[DocumentContractAmendment]` | `amendments`; empty when absent or null |
| `createdAt` | `String?` | `created_at` |
| `updatedAt` | `String?` | `updated_at` |

`ContractExternalReference` exposes `system: String` and `id: String`, with
Codable support; response omission defaults either field to an empty string.
All other optional contract fields stay nil when absent or null. Dates and
timestamps remain the API's strings. Prefer `NSDecimalNumber(string:)` when
constructing monetary inputs so no binary floating-point rounding occurs before
the SDK receives them.

| `DocumentContractAmendment` property | Type | Wire field / behavior |
| --- | --- | --- |
| `resource` | `String?` | `resource` |
| `documentId` | `String?` | `document_id`, this instrument |
| `documentName` | `String?` | `document_name` |
| `parentDocumentId` | `String?` | `parent_document_id`, the root contract document |
| `relationType` | `String?` | `relation_type` |
| `number` | `NSNumber?` | `number`; position among applied instruments, nil while pending |
| `status` | `String?` | `status`; `pending` or `applied` |
| `documentStatus` | `String?` | `document_status`; independent signing status |
| `applyError` | `String?` | `apply_error`; why application is waiting |
| `currency` | `String?` | `currency`; currency of the delta and change record |
| `termsJSON` | `JSONValue?`, Swift-only | `terms`; sparse delta |
| `terms` | `[String: Any]?` | Foundation/Objective-C dictionary view of `termsJSON` |
| `changesJSON` | `JSONValue?`, Swift-only | `changes`; `{field: {from, to}}` preview or applied record |
| `changes` | `[String: Any]?` | Foundation/Objective-C dictionary view of `changesJSON` |
| `appliedAt` | `String?` | `applied_at`; nil while pending |
| `createdAt` | `String?` | `created_at` |
| `updatedAt` | `String?` | `updated_at`; the link's concurrency timestamp |

The dynamic delta and change record use the existing `JSONValue` representation:
integers retain their integer representation, fractional numbers use `Double`,
and explicit null is `.null` / `NSNull`. These dynamic amounts are for inspecting
the record; use the root contract's decimal `value` for exact monetary
calculations. A null `terms` or `changes` has a nil Foundation dictionary while
its Swift JSON representation retains `.null`.

`DocumentDetails`, `DocumentListItem`, `DocumentUploadResponse`, and
`PublicDocumentInfo` expose `hasContract: NSNumber?` from `has_contract`.
True/false are retained; nil means the API omitted the flag or did not resolve it.
The API supplies this flag on the workspace direct document-detail read while
contract tracking is enabled, excluding signer reads, lists, and webhooks.

### Lifecycle events and errors

The hourly lifecycle uses the Brasília calendar day. For active contracts it
records the renewal notice at the start of the notice period, expiry warnings
45 and 30 days before the end date, and renewal or expiration the day after the
end date. An owner's departure causes reassignment to the first owner still an
active member, or no owner if none remains. Notifications go to the first active
member among the contract owner and document creator, according to that member's
notification preferences.

When contract tracking is unavailable on the plan, automatic lifecycle changes
pause and signed instruments wait. When it becomes available, the hourly run
catches up on the contract's renewal cycle or expires it, and applies waiting
instruments in signing order. It does not send alerts whose windows passed.

Changes appear in document activities and webhooks, including
`document_contract_updated`, `document_contract_amendment_updated`,
`document_contract_amended`, `document_contract_renewal_notice`,
`document_contract_expiring`, `document_contract_expired`,
`document_contract_renewed`, and `document_contract_terminated`.

| Failure | SDK behavior |
| --- | --- |
| `400` contract rule violation | `APIError`; `responseData.errors` retains each `{field, code, message}` entry. `field` may be null for a whole-request error. The top-level message is the first entry's message. Invalid JSON can fail before this validation and omit `errors`. |
| `403` tracking unavailable or insufficient authorization | `APIError`; OAuth missing-scope challenges remain available through `insufficientScope`. |
| `404`, `code: "NoContractTerms"` | Document exists in the workspace but has no readable terms. An absent/out-of-workspace document also returns `404`, without this code. |
| `409`, `code: "ContractChanged"` | No write applied; read and reconcile before submitting again. |

`responseData` is available to Objective-C through `NSError.userInfo["responseData"]`.
The SDK preserves the error payload without introducing a separate CLM error type.

### Objective-C completions

Every async operation has an explicit completion form delivered on the **main queue**.
Payloads, params, response models, `NSDecimalNumber`, and `NSNumber` are usable from
Objective-C; the raw `JSONValue` properties remain Swift-only with dictionary views.

| Selector | Completion result |
| --- | --- |
| `listContractsWithParams:accountId:completion:` | `[DocumentContract]?`, error; items only |
| `getContractWithDocumentId:accountId:completion:` | `ContractDetails?`, error |
| `updateContractWithDocumentId:payload:accountId:completion:` | `ContractDetails?`, error |
| `relatedContractWithDocumentId:accountId:completion:` | `DocumentContract?`, error |
| `renewContractWithDocumentId:payload:accountId:completion:` | `DocumentContract?`, error |
| `terminateContractWithDocumentId:payload:accountId:completion:` | `DocumentContract?`, error |
