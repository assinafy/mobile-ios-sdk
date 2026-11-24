# Assinafy SDK for iOS

A dependency-free Swift 6.3+ SDK (language mode 6) for the Assinafy v1 API. It supports iOS 16+ and macOS 12+, with `async/await` APIs and Objective-C adapters that return on the main queue.

[Português](README.md) · [Complete reference](docs/API_REFERENCE.md) · [JSON payloads](docs/PAYLOADS.md) · [Assinafy API](https://api.assinafy.com.br/v1/docs)

## Installation

Add this repository as a Swift Package in Xcode, or declare:

```swift
.package(url: "https://github.com/assinafy/mobile-ios-sdk.git", from: "1.15.1")
```

The product is `Assinafy`. Import it with `import Assinafy`.

## Authentication

Use one credential per client. Never distribute an API key in a third-party application.

```swift
let workspaceClient = AssinafyClient(
    apiKey: apiKey,
    defaultAccountId: accountId
)

let userClient = AssinafyClient(
    token: accessToken,
    defaultAccountId: selectedAccountId
)
```

The transport requires HTTPS/TLS 1.2+, refuses token and revocation redirects, and never retries a request automatically.

## OAuth 2.1 with PKCE

Marketplace apps are public clients: exact HTTPS callback, PKCE S256, and no `client_secret`. OAuth is available only in production.

```swift
let publicClient = AssinafyClient(configuration: AssinafyClientConfiguration())
let resource = try await publicClient.oauth.protectedResourceMetadata()
let server = try await publicClient.oauth.authorizationServerMetadata(
    issuer: resource.authorizationServers[0]
)
let request = OAuthAuthorizationRequest(
    clientId: clientId,
    redirectURI: "https://app.example.invalid/oauth/callback",
    scopes: [.documentsRead, .documentsWrite, .accountRead, .openID, .offlineAccess],
    resource: resource.resource
)
let authorizationURL = request.authorizationURL(endpoint: server.authorizationEndpoint)!
```

Open `authorizationURL` with `ASWebAuthenticationSession` and retain `request` until the callback. The SDK generates fresh PKCE, `state`, and `nonce` values. Validate `state` and `iss` before exchanging the code:

```swift
let code = try OAuthCallback(callbackURL: callbackURL)!
    .validate(against: request, issuer: server.issuer)
let token = try await publicClient.oauth.exchangeAuthorizationCode(
    .authorizationCode(
        code: code,
        redirectURI: request.redirectURI,
        codeVerifier: request.pkce.codeVerifier,
        clientId: clientId,
        resource: resource.resource
    )
)
```

If you use the `id_token`, validate its signature, `iss`, `aud`, `exp`, and the `nonce` from `request`. Alternatively, read identity with `oauth.userInfo()`. The advertised introspection endpoint requires confidential credentials and is not a mobile-app operation.

After the exchange:

1. Save tokens in Keychain.
2. List `userClient.workspaces.list()`, let the user choose a workspace, and set its ID as `defaultAccountId`.
3. Refresh once at a time per connection. Every refresh rotates the refresh token; persist the new value before using the access token.
4. If the refresh outcome is uncertain, never reuse the token that was sent; reconnect the user.
5. On disconnect, revoke the latest refresh token once and delete local token storage.

OAuth tokens obey scopes and cannot access billing, account lifecycle, administration, or API keys.

## Complete signing flow

The flow is upload → processing → signers → estimate → assignment → confirmation/verification → signing → certification and download.

```swift
let options = AssinafyClient.UploadOptions(signers: [
    .init(name: "Example Person", email: "signer@example.invalid")
])
let result = try await workspaceClient.uploadAndRequestSignatures(
    documentData: pdfData,
    options: options
)
```

The helper creates a virtual email assignment. For full control, call `documents.upload`, `documents.waitUntilReady`, `signers.create`, `assignments.estimateCost`, and `assignments.create`. A failure after upload does not roll back resources already created. Idempotent signer creation may reuse an email match without updating it; update reused signers explicitly.

### Verification and notification methods

| Verification | Requirements | Experience |
| --- | --- | --- |
| `Bypass` | VerificationBypass feature enabled | No OTP; optionally embedded without notification |
| `Email` | Exactly one Email notification | OTP checked by `signers.verifyEmail` before native signing |
| `Whatsapp` | Enabled feature, phone, and one Whatsapp notification | OTP through Whatsapp |
| `IdDocumentFaceMatchBasic` | Enabled feature, CPF, and Email or Whatsapp | Explicit consent, ID capture, and selfie; workspace review may be required |
| `DigitalCertificate` | Enabled feature, CPF/CNPJ, virtual assignment, and signer alone in the step | ICP-Brasil A1 or A3 certificate through the web page and Web PKI |

Call `assignments.estimateCost` before creating the assignment. Whatsapp, biometric, and certificate verification may consume credits. A1/A3 never uploads a private key to this SDK: open the signing URL in the browser.

In the biometric flow, the signer reads `signers.identityVerification` and calls `startIdentityVerification` only after consent and `canStart`. Preserve the URL fragment and treat the URL as a secret. `pending_identity_review` permits signing but holds certification. The workspace reads `assignments.identityReview`; evidence images and review decisions require a direct workspace credential.

The signer confirms data and terms, verifies the OTP when required, signs, and downloads artifacts through `signer-access-code` routes. Those calls never carry the workspace credential. Exact calls are in the [reference](docs/API_REFERENCE.md#signers) and [payload catalog](docs/PAYLOADS.md).

## Envelopes and embedded signing

Group 1–20 processed documents with `envelopes.estimateCost` and `envelopes.create`. Each document keeps its own assignment, status, and certification; each signer receives one group invitation. Envelopes have no ordered signing steps. `envelopes.update` changes the name, message, or order; `addDocument`, `removeDocument`, `cancel`, and `delete` manage the lifecycle. Removal cancels the document; deletion requires all documents closed and preserves them.

For envelopes and templates, persist the `Idempotency-Key` with the payload before sending and reuse both after an uncertain result. `maxTotalCredits` caps spending on assignments, envelopes, added documents, and templates; exceeding the ceiling rejects the operation.

For an embedded signer, set their ID in `embeddedSignerIds` (or `TemplateSigner.embedded`), register the HTTPS origin with `workspaces.addEmbedOrigin`, and call `assignments.createEmbedSession`. Open its single-use URL in an iframe on that origin within five minutes; keep credentials on the backend. Do not treat `signing_urls` as access codes: email invitations request access, while Whatsapp/embedded entries may have `url: null`.

Use `getSigningDocument(..., expand: ["envelope"], documentId: ...)` to navigate the group and `signMultipleDocuments` to sign together. When `isSignerAccessClosed` is true, show only status and `certifiedCopy`; `resendCertifiedCopy` sends to the original contact. `downloadCertifiedCopy` takes the new link's token; expired links raise error 302. Signer-code downloads provide only `original`; certified copies use a download token.

`workspaces.notificationPolicy` controls team events; `auth.getPushPreferences` and email preferences control the user. Workspace policy takes precedence. `workspaces.get(..., expand: ["signing_features"])` reports enabled features; `usage` requires a direct credential and refuses OAuth.

## Scheduling and delivery tracking

On staging (`https://api.angry-pisco.stage.assinafy.com.br/v1`), use `assignments.schedule` or `envelopes.schedule` with `sendAt` between one hour and 90 days ahead. List, cancel, or send immediately through `assignments`; execution uses current prices and respects `maxTotalCredits`. After an uncertain response, list scheduled sends before creating another.

Assignment payload `signerCapacities` sets each signer’s capacity, such as `Witness`. `documents.setWatchers` registers up to ten contacts to receive the outcome without signing. Read `documents.signerCapacities` and `documents.notificationHistory`; email opens do not prove human reading. `envelopes.estimateResendCost` prices a reminder before sending. These operations are also available on staging.

## Templates, contracts, and fields

- `templates` creates documents from roles and positions collect fields by page.
- `fields` creates, updates, and validates definitions; `tags` organizes documents.
- `contracts` manages terms, renewals, terminations, and amendment instruments. Send `updated_at` for optimistic concurrency and preserve the original request after an uncertain outcome.
- `documents` exposes paginated activities and `original`, `certificated`, `certificate-page`, `pades`, and `bundle` artifacts.

## Signed webhooks

Create endpoints with `webhooks.createEndpoint`. When `signing_enabled` is enabled, save the one-time `secret` on the receiving server. Verify `webhook-id`, `webhook-timestamp`, and `webhook-signature` over the raw body:

```swift
guard WebhookSignature.verify(
    body: rawBody,
    id: headers["webhook-id"] ?? "",
    timestamp: headers["webhook-timestamp"] ?? "",
    signatureHeader: headers["webhook-signature"] ?? "",
    secret: secret
) else { throw AssinafySDKError("Invalid webhook signature") }
```

`webhooks.testEndpoint` sends a test event without changing endpoint state and returns the delivery attempt.

Verification uses HMAC-SHA256 and a 300-second window. Deduplicate verified deliveries by `webhook-id`. Rotation invalidates the old secret immediately. OAuth apps can rotate with `webhooks:write`, but cannot read an existing secret.

## Objective-C, errors, and limits

Every public async method has an explicit completion-handler form delivered on the main queue. Swift types without an Objective-C representation have raw-string or JSON overloads.

Errors are `ValidationError`, `APIError`, `NetworkError`, `MFARequiredError`, or `AssinafySDKError`. `APIError` preserves `X-Rate-Limit-Limit`, `X-Rate-Limit-Remaining`, `X-Rate-Limit-Reset`, `Retry-After`, OAuth details, and insufficient scope. The SDK does not choose when to retry; use the operation's semantics.

## Environments and validation

- Production: `https://api.assinafy.com.br/v1`
- Sandbox: `https://sandbox.assinafy.com.br/v1`
- OAuth, MFA, and biometrics may be production-only; check the reference before planning tests.

```bash
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build -c release -Xswiftc -warnings-as-errors
```

Local unit tests do not access the network. Live tests require environment variables and are restricted to sandbox; public OAuth discovery has a separate flag. Never store credentials, private callbacks, or real recipients in the repository.

## Documentation

- [API_REFERENCE.md](docs/API_REFERENCE.md): every method, parameter, model, Objective-C selector, and credential rule.
- [PAYLOADS.md](docs/PAYLOADS.md): complete request bodies and synthetic response examples.
- [CHANGELOG.md](CHANGELOG.md): release history.
- [Official documentation](https://api.assinafy.com.br/v1/docs): live API contract.
