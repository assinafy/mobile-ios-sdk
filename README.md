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
    .package(url: "https://github.com/assinafy/assinafy-sdk-ios.git", from: "1.1.0")
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

### Create Assignment

```swift
let assignment = try await client.assignments.create(
    documentId: document.id,
    payload: .withSignerIds([signer.id], method: .virtual)
)
```

## Resources

The SDK exposes seven resource objects:

- `client.documents` - Document uploads, downloads, and management
- `client.signers` - Signer creation and management
- `client.assignments` - Signing assignments
- `client.webhooks` - Webhook subscriptions
- `client.templates` - Document templates
- `client.workspaces` - Workspace management
- `client.auth` - Login, password reset, and API key management

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
