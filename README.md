# Assinafy iOS SDK

Native Swift and Objective-C access to the [Assinafy v1 API](https://api.assinafy.com.br/v1/docs) for documents, signers, assignments, fields, tags, templates, workspaces, webhooks, and authentication.

## Requirements

- iOS 16.0+
- macOS 12.0+ for macOS consumers
- Swift 6.3+
- Xcode 26.6+

Swift and Xcode do not use an LTS release channel. These versions are the current stable toolchain supported by this package.

## Installation

Add the package and product to `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/assinafy/mobile-ios-sdk.git",
        from: "1.3.1"
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

In Xcode, select **File → Add Package Dependencies…** and enter the repository URL.

## Authentication and configuration

Use bearer tokens in distributed mobile apps. Permanent API keys belong in a trusted backend and must not be embedded in an app bundle.

```swift
import Assinafy

let configuration = AssinafyClientConfiguration(
    token: bearerToken,
    defaultAccountId: accountId,
    timeout: 30
)
try configuration.validate()
let client = AssinafyClient(configuration: configuration)
```

For public operations such as login and password reset, credentials may be omitted:

```swift
let publicClient = AssinafyClient(
    configuration: AssinafyClientConfiguration()
)

let session = try await publicClient.auth.login(
    LoginPayload(email: email, password: password)
)
```

Configuration fails closed. Requests are rejected before network I/O when credentials conflict, a timeout is invalid, an identifier is unsafe, or the base URL is not an absolute HTTPS URL without user information, query, or fragment.

## Complete document flow

The following function is a complete owner-side flow: upload, wait for processing, create or reuse a signer, estimate cost, create an assignment, inspect status, and download the original PDF.

```swift
import Assinafy
import Foundation

struct SignatureRequestResult {
    let document: DocumentUploadResponse
    let signer: Signer
    let assignment: Assignment
    let originalPDF: Data
}

func requestSignature(
    pdfData: Data,
    bearerToken: String,
    accountId: String,
    signerName: String,
    signerEmail: String
) async throws -> SignatureRequestResult {
    let configuration = AssinafyClientConfiguration(
        token: bearerToken,
        defaultAccountId: accountId
    )
    try configuration.validate()
    let client = AssinafyClient(configuration: configuration)

    let uploaded = try await client.documents.upload(pdfData)
    let document = try await client.documents.waitUntilReady(
        documentId: uploaded.id,
        options: WaitUntilReadyOptions(
            maxWaitSeconds: 60,
            pollIntervalSeconds: 2
        )
    )

    let signer = try await client.signers.create(
        CreateSignerPayload(fullName: signerName, email: signerEmail)
    )

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
        throw AssinafySDKError(
            estimate.blockingReason ?? "Insufficient account resources"
        )
    }

    let assignment = try await client.assignments.create(
        documentId: document.id,
        payload: request
    )
    _ = try await client.documents.getSigningProgress(documentId: document.id)
    _ = try await client.documents.activities(documentId: document.id)

    let originalPDF = try await client.documents.downloadArtifact(
        documentId: document.id,
        artifact: .original
    )
    return SignatureRequestResult(
        document: document,
        signer: signer,
        assignment: assignment,
        originalPDF: originalPDF
    )
}
```

The convenience `uploadAndRequestSignatures` performs the same owner-side orchestration. It validates all signer input before uploading, but the remote steps are not transactional. If a later request fails, the already-created document or signers remain available for explicit cleanup or retry.

## Signer flow

A signer access code comes from the signing invitation and is sent as the exact `signer-access-code` query parameter. It must be treated as a secret.

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
    try await client.signers.acceptTermsWithoutResponse(
        signerAccessCode: accessCode
    )
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

Public token delivery uses one request and returns `Void`:

```swift
try await publicClient.documents.sendPublicSignToken(
    documentId: documentId,
    email: "recipient@example.invalid"
)
```

## Fields and JSON values

String validation remains source-compatible. Use `JSONValue` when a field accepts another JSON type:

```swift
let result = try await client.fields.validate(
    fieldId: fieldId,
    value: JSONValue(.integer(42))
)
```

Untyped response fields also expose lossless JSON alongside legacy string or Foundation views:

- `DocumentActivity.originJSON` and `payloadJSON`
- `AssignmentItem.valueJSON`
- `TemplateFieldPlacement.displaySettingsJSON`
- `WebhookDispatch.payloadJSON`

## Tags and templates

```swift
let tag = try await client.tags.create(
    CreateTagPayload(name: "Contracts", color: "ff8800")
)
_ = try await client.tags.appendDocumentTags(
    documentId: documentId,
    tagIds: [tag.id]
)

let templates = try await client.templates.list(
    params: TemplateListParams(search: "Hiring")
)
```

Template listing and document creation from a template use the v1 contract.
Template-definition create, get, update, and delete are compatibility methods;
confirm their availability for the configured environment before depending on
them.

## Resource map

- `client.auth`: login, social login/linking, password operations, API-key management, current user, notification preferences, user statistics
- `client.workspaces`: account CRUD, theme, statistics, logo upload/download/delete
- `client.documents`: upload, list/search/get/rename/delete, processing status, pages, thumbnails, activities, artifacts, verification, template document creation, public token flow
- `client.signers`: workspace signer CRUD plus signer self-service, terms, verification, signatures, signer documents, batch sign/decline
- `client.assignments`: list, create, estimate, sign/decline, resend, expiration, WhatsApp notifications
- `client.fields`: definitions, field types, single and batch validation
- `client.tags`: workspace tags and document attachments
- `client.templates`: template listing and compatible definition management
- `client.webhooks`: subscriptions, event types, delivery history, and retry

See [docs/API_REFERENCE.md](docs/API_REFERENCE.md) for each method's authentication, HTTP path, request payload, response payload, compatibility behavior, and error model.

## Errors

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
    // The SDK preserves Swift task cancellation.
}
```

Cross-origin HTTPS download redirects are allowed only for bodyless `GET` and
`HEAD`. Only `Accept`, `Accept-Encoding`, `Accept-Language`, `Range`, `If-Range`,
and `User-Agent` survive. Credential, cookie, and unknown custom headers are
removed. HTTP downgrades, user-information URLs, and cross-origin body redirects
are refused.

## Testing

Run strict host tests and a release build:

```bash
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

CI also runs XCTest on an iOS 26.5/iPhone 17 Pro simulator with Xcode 26.6,
builds DocC with warnings treated as errors, checks public API compatibility
against the nearest prior tag, and verifies that release tags, `sdkVersion`,
and the changelog agree.

Live tests accept credentials only through the environment and refuse every host except `https://sandbox.assinafy.com.br/v1`:

```bash
ASSINAFY_API_KEY="..." \
ASSINAFY_ACCOUNT_ID="..." \
ASSINAFY_BASE_URL="https://sandbox.assinafy.com.br/v1" \
swift test --filter AssinafyTests.AssinafyLiveTests
```

Mutation tests require an explicit opt-in and two dedicated recipients supplied at runtime:

```bash
ASSINAFY_API_KEY="..." \
ASSINAFY_ACCOUNT_ID="..." \
ASSINAFY_BASE_URL="https://sandbox.assinafy.com.br/v1" \
ASSINAFY_RUN_LIVE_MUTATIONS=1 \
ASSINAFY_TEST_EMAIL_A="recipient-a@example.invalid" \
ASSINAFY_TEST_EMAIL_B="recipient-b@example.invalid" \
swift test --filter AssinafyTests.AssinafyLiveTests
```

Never commit live credentials, access codes, passwords, or recipient addresses.
The `Live Sandbox` GitHub workflow reads environment secrets, runs read-only
checks weekly, permits manually requested mutation runs, and runs the complete
mutation suite for every `v*` release tag. Complete runs fail when the sandbox
account lacks the resources needed to create an assignment.

## Objective-C

Objective-C-compatible methods use completion handlers delivered on the main queue. The generated header is the source of truth for selectors; not every Swift-concurrency helper has a completion wrapper.

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

Swift error types bridge to `NSError` domains in `ASFErrorDomain`. API status, validation fields, response data, and underlying transport errors are carried through `code` and `userInfo`.

## License

MIT. See [LICENSE](LICENSE).
