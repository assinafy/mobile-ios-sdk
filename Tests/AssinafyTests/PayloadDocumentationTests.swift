import XCTest
@testable import Assinafy

final class PayloadDocumentationTests: XCTestCase {
    func testResponseExamplesDecodeWithSDKModels() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("docs/PAYLOADS.md"), encoding: .utf8)
        let pattern = try NSRegularExpression(pattern: "### ([A-Za-z][A-Za-z0-9]*)\\n\\n```json\\n([\\s\\S]*?)\\n```")
        let examples = Dictionary(uniqueKeysWithValues: pattern.matches(in: source, range: NSRange(source.startIndex..., in: source)).map {
            (String(source[Range($0.range(at: 1), in: source)!]), Data(source[Range($0.range(at: 2), in: source)!].utf8))
        })
        func decode<T: Decodable>(_ name: String, as type: T.Type) throws {
            let data = try XCTUnwrap(examples[name], "Missing \(name) payload")
            XCTAssertNoThrow(try JSONDecoder.assinafy.decode(type, from: data), "\(name) payload")
        }
        try decode("AuthUser", as: User.self)
        try decode("AuthAccount", as: Account.self)
        try decode("AuthSession", as: LoginResponse.self)
        try decode("Signer", as: Signer.self)
        try decode("SignerSelf", as: SignerSelfInfo.self)
        try decode("DocumentPage", as: DocumentPage.self)
        try decode("DisplaySettings", as: DisplaySettings.self)
        try decode("DocumentStatus", as: DocumentStatusInfo.self)
        try decode("Document", as: DocumentDetails.self)
        try decode("Account", as: WorkspaceResponse.self)
        try decode("AccountTheme", as: AccountTheme.self)
        try decode("Field", as: FieldDefinition.self)
        try decode("Tag", as: Tag.self)
        try decode("SigningUrl", as: AssignmentSigningURL.self)
        try decode("AssignmentSigner", as: Signer.self)
        try decode("AssignmentItem", as: AssignmentItem.self)
        try decode("AssignmentSummary", as: AssignmentSummary.self)
        try decode("Assignment", as: Assignment.self)
        try decode("CostEstimate", as: CostEstimate.self)
        try decode("TemplateFieldPlacement", as: TemplateFieldPlacement.self)
        try decode("TemplatePage", as: TemplatePage.self)
        try decode("TemplateRole", as: TemplateRole.self)
        try decode("Template", as: TemplateDetails.self)
        try decode("WebhookSubscription", as: WebhookSubscription.self)
        try decode("WebhookDispatch", as: WebhookDispatch.self)
        try decode("WebhookEventType", as: WebhookEventTypeInfo.self)
        try decode("FieldType", as: FieldTypeInfo.self)
        try decode("FieldValidationResult", as: FieldValidationResult.self)
        try decode("DocumentVerification", as: DocumentVerification.self)
        try decode("DocumentActivity", as: DocumentActivity.self)
        try decode("WhatsappNotification", as: WhatsappNotification.self)
        try decode("DocumentStatsRow", as: DocumentStatsRow.self)
        try decode("NotificationPreferences", as: NotificationPreferences.self)
        try decode("WebhookEndpoint", as: WebhookEndpoint.self)
        try decode("WebhookSigningSecret", as: WebhookSigningSecret.self)
        try decode("MFAStatus", as: MFAStatus.self)
        try decode("TOTPEnrollment", as: TOTPEnrollment.self)
        try decode("RecoveryCodes", as: MFARecoveryCodes.self)
        XCTAssertThrowsError(
            try JSONDecoder.assinafy.decode(LoginResponse.self, from: XCTUnwrap(examples["MFAChallenge"]))
        ) { XCTAssertEqual(($0 as? MFARequiredError)?.mfaToken, "mfa_token_example_001") }
    }
}
