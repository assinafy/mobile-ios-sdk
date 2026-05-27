# Assinafy iOS SDK

A native iOS SDK for the Assinafy document signing API.

Official API reference: https://api.assinafy.com.br/v1/docs

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/assinafy/mobile-ios-sdk.git", from: "1.2.0")
]
```

Or in Xcode: **File → Add Packages…** and paste the repository URL.

## Quick Start

### Configuration

```swift
import Assinafy

// API key authentication (server-side use only — see security note below)
let client = AssinafyClient(
    apiKey: "your-api-key",
    defaultAccountId: "your-workspace-id"
)

// Or bearer token authentication (recommended for mobile apps)
let client = AssinafyClient(
    token: "your-bearer-token",
    defaultAccountId: "your-workspace-id"
)
```

> **Security:** Assinafy's API documentation recommends API keys only from trusted back-end systems. For mobile apps, fetch a short-lived bearer token from your own backend (or use the `auth.login` endpoint directly) instead of embedding a permanent `X-Api-Key` in the app bundle.

### Authentication

```swift
let unauthenticatedClient = AssinafyClient(configuration: AssinafyClientConfiguration())
let login = try await unauthenticatedClient.auth.login(
    LoginPayload(email: "user@example.com", password: "password")
)

let client = AssinafyClient(
    token: login.accessToken,
    defaultAccountId: login.accounts.first?.id
)
```

### Upload and Request Signatures

```swift
// Simple upload and sign flow
let (document, assignment) = try await client.uploadAndRequestSignatures(
    documentData: pdfData,
    options: AssinafyClient.UploadOptions(signers: [
        AssinafyClient.SignerInput(name: "John Doe", email: "john@example.com")
    ])
)
```

### Upload Document

```swift
let doc = try await client.documents.upload(
    pdfData,
    options: DocumentUploadOptions(accountId: "acc-id")
)
_ = try await client.documents.waitUntilReady(documentId: doc.id)
```

### Create Signers

```swift
let signer = try await client.signers.create(
    CreateSignerPayload(
        fullName: "John Doe",
        email: "john@example.com",
        whatsappPhoneNumber: "+5548999990000"
    )
)
```

### Tags

```swift
let tag = try await client.tags.create(
    CreateTagPayload(name: "Contracts", color: "ff8800")
)

_ = try await client.tags.appendDocumentTags(
    documentId: document.id,
    tagNames: [tag.name]
)
```

### Create Assignment

```swift
let assignment = try await client.assignments.create(
    documentId: document.id,
    payload: .withSignerIds([signer.id], method: .virtual)
)
```

### Signer-facing flows

The signer-facing endpoints expect a signer access code (delivered to the
signer by email or WhatsApp):

```swift
// Look up the current document
let doc = try await client.signers.getCurrentDocument(
    signerId: signerId,
    signerAccessCode: code
)

// Confirm the signer's data before signing (virtual assignments only)
try await client.documents.confirmSignerData(
    documentId: doc.id,
    signerAccessCode: code,
    payload: ConfirmSignerDataPayload(email: signer.email, hasAcceptedTerms: true)
)

// Sign or decline the assignment
try await client.assignments.sign(
    documentId: doc.id,
    assignmentId: doc.assignment!.id,
    signerAccessCode: code
)
// or
try await client.assignments.decline(
    documentId: doc.id,
    assignmentId: doc.assignment!.id,
    signerAccessCode: code,
    reason: "Terms unacceptable."
)
```

### Validating field values

```swift
let result = try await client.fields.validate(
    fieldId: cpfDefinition.id,
    value: "400.676.228-36"
)
print(result.success, result.errorMessage)
```

### Templates

```swift
let template = try await client.templates.create(
    name: "Hiring contract",
    pdfData: contractPDF
)

_ = try await client.templates.update(
    templateId: template.id,
    payload: UpdateTemplatePayload(message: "Please sign within 7 days")
)

let generated = try await client.documents.createFromTemplate(
    templateId: template.id,
    signers: [
        TemplateSigner(
            roleId: "role-id",
            id: signer.id,
            verificationMethod: "Email",
            notificationMethods: ["Email"],
            step: NSNumber(value: 1)
        )
    ],
    options: CreateDocumentFromTemplateOptions(
        name: "Hiring contract - John.pdf",
        editorFields: [TemplateEditorField(fieldId: "field-id", value: "Acme")],
        tags: ["Onboarding"]
    )
)
```

## Resources

The SDK exposes resource objects for the public API documented at https://api.assinafy.com.br/v1/docs:

- `client.documents` - Document uploads, downloads, management, public lookup, signing token delivery, status catalog
- `client.signers` - Signer CRUD, self-service flows, signer-facing document listing/sign-multiple/decline-multiple/download
- `client.assignments` - Signing assignments: create, sign, decline, resend, cost estimation, reset expiration, WhatsApp notification log
- `client.webhooks` - Webhook subscriptions, event-type catalog, dispatch history, retry
- `client.templates` - Document template CRUD (create, list, get, update, delete) and instantiation
- `client.tags` - Workspace tag CRUD and document tag listing/replacement/append/detach
- `client.workspaces` - Workspace (account) CRUD
- `client.fields` - Field-definition CRUD, value validation (single and batch), field type catalog
- `client.auth` - Login, social login, password reset, change password, API key management

## Testing

Run the unit suite:

```bash
swift test
```

Live API checks are gated by environment variables and are skipped by default:

```bash
ASSINAFY_API_KEY="..." ASSINAFY_ACCOUNT_ID="..." swift test --filter AssinafyLiveTests
```

The live suite exercises read-only catalog/list endpoints plus isolated tag and signer CRUD with cleanup. Add `ASSINAFY_RUN_DOCUMENT_LIVE_TESTS=1` to also run upload/get/download/delete against a generated test PDF. Do not commit live credentials.

## Error Handling

```swift
do {
    let doc = try await client.documents.upload(data)
} catch let error as APIError {
    // Handle API errors (4xx, 5xx responses)
    print("API Error: \(error.statusCode) - \(error.message)")
} catch let error as ValidationError {
    // Handle validation errors
    print("Validation: \(error.message)")
} catch let error as NetworkError {
    // Handle network errors
    print("Network: \(error.message)")
}
```

## Objective-C Support

The SDK is fully compatible with Objective-C:

```objc
ASFAssinafyClient *client = [[ASFAssinafyClient alloc] initWithApiKey:@"key"
                                                        defaultAccountId:@"acc"];

[client.signers getSignerWithId:@"signer-id" accountId:nil completion:^(ASFSigner *signer, NSError *error) {
    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }
    NSLog(@"Signer: %@", signer.fullName);
}];
```

## License

MIT License - see LICENSE file for details.
