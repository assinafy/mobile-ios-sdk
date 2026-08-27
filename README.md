# Assinafy iOS SDK

Native Swift and Objective-C access to the [Assinafy v1 API](https://api.assinafy.com.br/v1/docs):
documents, signers, assignments, fields, tags, templates, workspaces, webhooks, and
authentication.

The SDK covers every operation in the published v1 OpenAPI document. Requests are
`async`/`await` first, with completion-handler wrappers for Objective-C. Responses decode into
typed models, and failures surface as four distinct Swift error types that bridge cleanly to
`NSError`.

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Configuring the client](#configuring-the-client)
- [How credentials are sent](#how-credentials-are-sent)
- [The signing lifecycle](#the-signing-lifecycle)
- [The signer's side of the flow](#the-signers-side-of-the-flow)
- [Templates](#templates)
- [Tags, fields, and untyped JSON](#tags-fields-and-untyped-json)
- [Workspaces and webhooks](#workspaces-and-webhooks)
- [Pagination](#pagination)
- [Handling errors](#handling-errors)
- [Transport and network security](#transport-and-network-security)
- [Objective-C](#objective-c)
- [Resource map](#resource-map)
- [Testing](#testing)
- [Versioning](#versioning)
- [License](#license)

## Requirements

| | |
| --- | --- |
| iOS | 16.0+ |
| macOS | 12.0+ |
| Swift | 6.3+ (language mode 6) |
| Xcode | 26.6+ |

Swift and Xcode have no LTS release channel. These are the current stable toolchain versions
this package builds and tests against.

## Installation

Add the package and product to `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/assinafy/mobile-ios-sdk.git",
        from: "1.4.0"
    ),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "Assinafy", package: "mobile-ios-sdk"),
        ]
    ),
]
```

In Xcode, choose **File → Add Package Dependencies…** and enter the repository URL.

## Quick start

Send one PDF to one signer:

```swift
import Assinafy

let client = AssinafyClient(token: bearerToken, defaultAccountId: accountId)

let uploaded = try await client.documents.upload(pdfData)
let document = try await client.documents.waitUntilReady(documentId: uploaded.id)

let signer = try await client.signers.create(
    CreateSignerPayload(fullName: "Ana Souza", email: "ana@example.invalid")
)

let assignment = try await client.assignments.create(
    documentId: document.id,
    payload: .withSignerIds([signer.id], method: .virtual, message: "Please review and sign.")
)
```

Each of those steps is explained under [The signing lifecycle](#the-signing-lifecycle).

## Configuring the client

Create one client and hold a strong reference to it. `AssinafyClient` is thread-safe and its
resource objects are stateless views over a shared transport.

```swift
import Assinafy

let configuration = AssinafyClientConfiguration(
    token: bearerToken,        // or apiKey:, never both
    baseURL: AssinafyClientConfiguration.productionBaseURL,
    defaultAccountId: accountId,
    timeout: 30,
    logger: NoopLogger()
)
try configuration.validate()
let client = AssinafyClient(configuration: configuration)
```

**Choose the credential that matches where the code runs.** Bearer tokens belong in
distributed mobile apps. A permanent API key grants standing access to the whole workspace and
belongs in a trusted backend — never in an app bundle, where it can be extracted.

`defaultAccountId` is applied to every account-scoped call. Any method that takes an
`accountId` argument overrides it for that call.

Configuration fails closed. `validate()` rejects conflicting or malformed credentials, a
non-positive or non-finite timeout, an unsafe identifier, and any base URL that is not an
absolute HTTPS URL free of user information, query, and fragment. The same checks run on every
request, so a client built without calling `validate()` throws `ValidationError` before it
performs network I/O rather than sending a malformed request.

Some operations need no credential at all. Leave both out for login, password reset, and the
public document routes:

```swift
let publicClient = AssinafyClient(configuration: AssinafyClientConfiguration())

let session = try await publicClient.auth.login(
    LoginPayload(email: email, password: password)
)
```

## How credentials are sent

The v1 API places every operation in one of three authentication classes, and the SDK enforces
that split rather than attaching credentials indiscriminately.

| Class | How the API authenticates it | What the SDK sends |
| --- | --- | --- |
| **Account** | `Authorization: Bearer {token}` or `X-Api-Key: {key}` | The configured credential header |
| **Signer** | The exact `signer-access-code={code}` query parameter | The query parameter only |
| **Public** | Nothing | Nothing |

A client configured with a bearer token or API key does **not** transmit it to a Signer or
Public operation. This means one client can serve both sides of a flow: the same instance can
manage documents with an account credential and drive a signer through `assignments.sign(…)`
without that credential leaving the routes that accept it.

Access codes are secrets. Treat a `signerAccessCode` exactly as you would a password: never log
it, never persist it beyond the signing session, and never place it in a URL you share.

If you build requests directly against `HTTPClientProtocol`, `APIRequest.credential` carries
the class and `APIRequest.withoutWorkspaceCredential()` returns a copy that carries no
credential. See [`docs/API_REFERENCE.md`](docs/API_REFERENCE.md#low-level-request-and-transport-api).

## The signing lifecycle

A signature request moves through five stages. Each has a dedicated SDK call.

```
upload ──▶ wait for processing ──▶ create signers ──▶ estimate ──▶ create assignment
```

### 1. Upload the document

```swift
let uploaded = try await client.documents.upload(
    pdfData,
    options: DocumentUploadOptions(accountId: accountId)
)
```

The SDK checks the PDF magic bytes and the 25 MB platform limit locally, so an invalid file
fails immediately with `ValidationError` instead of consuming a round-trip.

### 2. Wait for processing

A freshly uploaded document is `metadata_processing` and cannot yet be assigned or deleted.
Poll until it is ready:

```swift
let document = try await client.documents.waitUntilReady(
    documentId: uploaded.id,
    options: WaitUntilReadyOptions(maxWaitSeconds: 60, pollIntervalSeconds: 2)
)
```

`waitUntilReady` returns as soon as the document reaches `metadataReady`, `pendingSignature`,
`certificating`, or `certificated`. It throws `AssinafySDKError` on a terminal status
(`failed`, `expired`, `rejectedBySigner`, `rejectedByUser`) or when the deadline passes, and it
honours task cancellation throughout.

### 3. Create the signers

```swift
let signer = try await client.signers.create(
    CreateSignerPayload(fullName: "Ana Souza", email: "ana@example.invalid")
)
```

Creation is idempotent by email: the SDK looks for an existing signer with the same address and
returns it instead of creating a duplicate, and it recovers the same way from a `409`. Signers
may also be created with a full name alone.

### 4. Estimate the cost

Signature requests consume documents and credits. Check before committing:

```swift
let request = CreateAssignmentPayload.withSignerIds(
    [signer.id],
    method: .virtual,
    message: "Please review and sign."
)

let estimate = try await client.assignments.estimateCost(
    documentId: document.id,
    payload: request
)
guard estimate.hasSufficientResources else {
    throw AssinafySDKError(estimate.blockingReason ?? "Insufficient account resources")
}
```

`CostEstimate` carries the typed `breakdown`, the current `documentBalance` and
`creditBalance`, and a `blockingReason` of `PendingPayment`, `InsufficientDocuments`, or
`InsufficientCredits`.

### 5. Create the assignment

```swift
let assignment = try await client.assignments.create(
    documentId: document.id,
    payload: request
)
```

Use `.virtual` for remote signing by notification, and `.collect` for in-person field
collection, which additionally requires page field placements. For ordered signing, build
signers with `SignerReference.descriptor(id:verificationMethod:notificationMethods:step:)`
and assign each a `step`.

### Tracking and retrieving the result

```swift
let progress = try await client.documents.getSigningProgress(documentId: document.id)
let done     = try await client.documents.isFullySigned(documentId: document.id)
let history  = try await client.documents.activities(documentId: document.id)

let signedPDF = try await client.documents.downloadArtifact(
    documentId: document.id,
    artifact: .certificated
)
```

Artifacts are `.original`, `.certificated`, `.certificatePage`, `.pades`, and `.bundle`.
Thumbnails and single pages have their own methods. Anyone holding a signature hash can confirm
a finished document without credentials:

```swift
let verification = try await client.documents.verifyDetails(signatureHash: hash)
```

### Doing all of it in one call

`uploadAndRequestSignatures` performs the same owner-side orchestration:

```swift
let options = AssinafyClient.UploadOptions(signers: [
    AssinafyClient.SignerInput(name: "Ana Souza", email: "ana@example.invalid"),
])
options.message = "Please review and sign."

let (document, assignment) = try await client.uploadAndRequestSignatures(
    documentData: pdfData,
    options: options
)
```

It validates every signer — non-empty names, well-formed addresses, no duplicate
case-insensitive emails — before uploading, so bad input cannot leave an orphaned document
behind. The remote steps are not transactional: if a later step fails, the document and signers
already created remain available for retry or explicit cleanup.

## The signer's side of the flow

A signer arrives with an access code from their invitation. The full sequence is: read the
document, accept the terms, confirm identity data, then sign.

```swift
func signVirtualAssignment(
    client: AssinafyClient,
    documentId: String,
    assignmentId: String,
    accessCode: String,
    fullName: String,
    email: String
) async throws {
    _ = try await client.signers.getSelf(signerAccessCode: accessCode)
    try await client.signers.acceptTermsWithoutResponse(signerAccessCode: accessCode)
    _ = try await client.documents.confirmSignerDataAndReturnSigner(
        documentId: documentId,
        signerAccessCode: accessCode,
        payload: ConfirmSignerDataPayload(
            fullName: fullName,
            email: email,
            hasAcceptedTerms: true
        )
    )
    try await client.assignments.sign(
        documentId: documentId,
        assignmentId: assignmentId,
        signerAccessCode: accessCode
    )
}
```

Confirming signer data is required for virtual assignments; signing without it returns `400`.
A signer may instead decline:

```swift
try await client.assignments.decline(
    documentId: documentId,
    assignmentId: assignmentId,
    signerAccessCode: accessCode,
    reason: "Wrong recipient"
)
```

Signers who hold several documents can act on them together with
`signers.signMultipleDocuments(…)` and `signers.declineMultipleDocuments(…)`, and can list
their own documents with `signers.listSignerDocuments(…)` and
`signers.searchSignerDocuments(…)`.

Signature and initial images are PNG:

```swift
try await client.signers.uploadSignature(
    signerAccessCode: accessCode,
    type: .signature,
    imageData: pngData,
    reuse: true
)
```

Where the signing link carries only an access code and no signer ID, use
`signers.getSigningDocument(signerAccessCode:)`.

Before a signer verifies their code, an app can show a public summary and send the six-digit
token:

```swift
let info = try await client.documents.getPublicInfo(documentId: documentId)

try await client.documents.sendPublicSignToken(
    documentId: documentId,
    email: "ana@example.invalid"
)
```

## Templates

Create documents from a reusable template by mapping template roles to signers:

```swift
let templates = try await client.templates.list(
    params: TemplateListParams(search: "Hiring")
)

let document = try await client.documents.createFromTemplate(
    templateId: templateId,
    signers: [TemplateSigner(roleId: roleId, id: signer.id)],
    options: CreateDocumentFromTemplateOptions(name: "Offer letter")
)
```

`documents.estimateCostFromTemplate(…)` prices the same request first.

Template listing and template-document creation are v1 operations. Template-definition
management — `templates.create(name:pdfData:)`, `get`, `update`, and `delete` — is available on
the live API but is not in the published OpenAPI document; confirm availability for your
environment before depending on it.

## Tags, fields, and untyped JSON

```swift
let tag = try await client.tags.create(
    CreateTagPayload(name: "Contracts", color: "ff8800")
)
_ = try await client.tags.appendDocumentTags(documentId: documentId, tagIds: [tag.id])
```

`tags.appendDocumentTags` adds to a document's tags; `tags.replaceDocumentTags` sets them
exactly, and passing an empty array clears them.

Field definitions describe values collected from signers. Validation accepts a plain `String`,
or a `JSONValue` when the field takes another JSON type:

```swift
let result = try await client.fields.validate(
    fieldId: fieldId,
    value: JSONValue(.integer(42))
)

let batch = try await client.fields.validateMultiple(items: [
    FieldValidateMultipleItem(fieldId: fieldId, value: "2026-08-27"),
])
```

Response fields whose schema intentionally allows any JSON type expose a lossless `JSONValue`
alongside the legacy string view:

- `DocumentActivity.originJSON` and `payloadJSON`
- `AssignmentItem.valueJSON`
- `TemplateFieldPlacement.displaySettingsJSON`
- `WebhookDispatch.payloadJSON`

## Workspaces and webhooks

`client.workspaces` maps to the account endpoints: create, read, update, delete, branding theme,
document-funnel statistics, and the account logo.

```swift
let theme = try await client.workspaces.theme()
try await client.workspaces.uploadLogo(pngData)
```

`theme()` is the canonical source of an account's branding colours.

Webhooks deliver document lifecycle events:

```swift
let subscription = try await client.webhooks.register(
    WebhookRegisterPayload(
        url: "https://example.invalid/hooks/assinafy",
        email: "ops@example.invalid",
        events: ["document.completed"]
    )
)

let types    = try await client.webhooks.listEventTypes()
let attempts = try await client.webhooks.listDispatches()
try await client.webhooks.retryDispatch(dispatchId: attempts.data[0].id)
```

The API has no destructive delete for subscriptions. Stop delivery with
`webhooks.inactivate()`; `webhooks.delete()` is deprecated and forwards to it.

## Pagination

List operations return `PaginatedResult<T>`. `data` holds the page; `meta` is built from the
`X-Pagination-*` response headers and is `nil` when the server omits them.

```swift
var page = 1
var all: [DocumentListItem] = []
repeat {
    let result = try await client.documents.list(params: ListParams(page: page, perPage: 100))
    all += result.data
    guard let meta = result.meta, page < meta.lastPage else { break }
    page += 1
} while true
```

## Handling errors

The SDK throws exactly four types, plus `CancellationError`:

| Type | Meaning | Key detail |
| --- | --- | --- |
| `APIError` | The API returned a non-2xx status | `statusCode`, `message`, `responseData` |
| `ValidationError` | Local validation failed before any request | `errors` field map |
| `NetworkError` | Transport failure — DNS, TLS, timeout | `underlyingError` as `URLError` |
| `AssinafySDKError` | An SDK contract violation | `context`, `underlyingError` |

```swift
do {
    _ = try await client.documents.get(documentId: documentId)
} catch let error as APIError {
    print(error.statusCode, error.message, error.responseData as Any)
    for restriction in error.workspaceDeletionRestrictions {
        print(restriction.code, restriction.accountIds)
    }
} catch let error as ValidationError {
    print(error.message, error.errors)
} catch let error as NetworkError {
    print(error.message, error.underlyingError as Any)
} catch is CancellationError {
    // Task cancellation is preserved rather than converted.
}
```

## Transport and network security

Requests go through an ephemeral `URLSession` with cookies and URL caching disabled, so no
credential or response is written to disk by the SDK.

Redirects are constrained. Same-origin redirects are followed unchanged. A cross-origin
redirect is accepted only when it is HTTPS, the method is `GET` or `HEAD`, and there is no
body — which covers artifact downloads served from another host. On such a redirect only
`Accept`, `Accept-Encoding`, `Accept-Language`, `Range`, `If-Range`, and `User-Agent` survive;
`Authorization`, `X-Api-Key`, `Cookie`, and every unknown header are stripped. HTTP downgrades,
destination URLs containing user information, and cross-origin redirects carrying a body are
refused outright.

## Objective-C

Objective-C-compatible methods take completion handlers, which are always delivered on the main
queue. The generated header is the source of truth for selectors; not every Swift-concurrency
helper has a completion wrapper.

```objc
ASFAssinafyClient *client = [[ASFAssinafyClient alloc]
    initWithToken:bearerToken
    defaultAccountId:accountId];

[client.signers getSignerWithId:@"signer-id"
                       accountId:nil
                      completion:^(Signer *signer, NSError *error) {
    if (error != nil) {
        NSLog(@"Request failed: %@", error.localizedDescription);
        return;
    }
    NSLog(@"Signer ID: %@", signer.id);
}];
```

Swift errors bridge to `NSError` under the domains in `ASFErrorDomain`. `code` carries the HTTP
status for `APIError`, `422` for `ValidationError`, the `URLError` code for `NetworkError`, and
`-1` for `AssinafySDKError`; details arrive in `userInfo` under `responseData`, `errors`, and
`NSUnderlyingErrorKey`.

## Resource map

| Resource | Coverage |
| --- | --- |
| `client.auth` | Login, social login and linking, password operations, API-key management, current user, notification preferences, user statistics |
| `client.workspaces` | Account CRUD, theme, statistics, logo upload/download/delete |
| `client.documents` | Upload, list/search/get/rename/delete, processing status, pages, thumbnails, activities, artifacts, verification, template document creation, public token flow |
| `client.signers` | Workspace signer CRUD, signer self-service, terms, verification, signature images, signer documents, batch sign and decline |
| `client.assignments` | List, create, estimate, sign, decline, resend, expiration, WhatsApp notifications |
| `client.fields` | Definitions, field types, single and batch validation |
| `client.tags` | Workspace tags and document attachments |
| `client.templates` | Template listing and definition management |
| `client.webhooks` | Subscriptions, event types, delivery history, retry |

[`docs/API_REFERENCE.md`](docs/API_REFERENCE.md) documents every method's authentication class,
exact HTTP path, request payload, response payload, compatibility behavior, and error model.

## Testing

Run the host suite with Swift 6 concurrency and warnings enforced, then a release build:

```bash
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

CI additionally runs XCTest on an iOS 26.5 / iPhone 17 Pro simulator under Xcode 26.6, builds
DocC with warnings treated as errors, checks public API compatibility against the nearest prior
tag, and verifies that a release tag, `sdkVersion`, the changelog, and this file all agree.

Live tests read credentials only from the environment and refuse every host except the sandbox:

```bash
ASSINAFY_API_KEY="..." \
ASSINAFY_ACCOUNT_ID="..." \
ASSINAFY_BASE_URL="https://sandbox.assinafy.com.br/v1" \
swift test --filter AssinafyTests.AssinafyLiveTests
```

Tests that create sandbox resources or send notifications need an explicit opt-in and two
distinct recipients supplied at runtime:

```bash
ASSINAFY_RUN_LIVE_MUTATIONS=1 \
ASSINAFY_TEST_EMAIL_A="recipient-a@example.invalid" \
ASSINAFY_TEST_EMAIL_B="recipient-b@example.invalid" \
swift test --filter AssinafyTests.AssinafyLiveTests
```

Never commit live credentials, access codes, passwords, or recipient addresses.

The `Live Sandbox` workflow reads its secrets from a GitHub environment. It runs the read-only
suite on every push to `main` and weekly on a schedule, and the complete mutation suite for
every `v*` release tag or when a maintainer requests one. Because live tests skip themselves
when credentials are absent — and a skipped run still exits zero — the workflow fails unless at
least one live test actually ran.

## Versioning

The package follows semantic versioning. Released versions are tagged `vMAJOR.MINOR.PATCH`, and
each is recorded in [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).
