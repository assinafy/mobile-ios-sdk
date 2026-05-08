# Changelog

## [1.1.0] - 2026-05-08

### Added
- Authentication endpoints for login, social login, password reset, and API key management
- Typed `CostEstimate` model returned by `assignments.estimateCost`, `assignments.estimateResendCost`, and `documents.estimateCostFromTemplate`
- `AssinafyClient.sdkVersion` constant exposed in the `User-Agent` header

### Changed
- Audit pass: stripped non-iOS Swift availability annotations and aligned every endpoint with https://api.assinafy.com.br/v1/docs
- Consolidated Objective-C completion-handler bridges through shared `BaseResource` helpers
- `User-Agent` header now reports the actual SDK version

### Removed
- Undocumented `metadata` multipart field from `documents.upload`
- Undocumented `sandboxBaseURL` constant; clients can still pass any base URL via `AssinafyClientConfiguration`

## [1.0.0] - 2024-01-01

### Added
- Initial release
- Document upload and management
- Signer CRUD operations
- Signing assignments (virtual and collect methods)
- Webhook subscriptions
- Document templates
- Workspace management
- Full Objective-C bridging support
- Swift async/await and completion handler APIs
