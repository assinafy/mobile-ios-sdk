import XCTest
@testable import Assinafy

final class CompletionAdapterTests: XCTestCase {
    func testAssignmentJSONRoundTripPreservesDescriptorsAndGeometry() throws {
        let original = CreateAssignmentPayload(
            method: .collect,
            signers: [.signer(id: "signer_1", verification: .email, notifications: [.email], step: 1)],
            entries: [AssignmentEntry(pageId: "page_1", fields: [
                AssignmentField(signerId: "signer_1", fieldId: "field_1", displaySettings:
                    DisplaySettings(left: 10, top: 20, width: 100, height: 40, fontSize: 16))
            ])],
            message: "Please sign", expiresAt: "2099-01-01T12:00:00Z", copyReceivers: ["copy_1"]
        )
        let data = try JSONEncoder.assinafy.encode(buildAssignmentBody(original))
        let decoded = try CreateAssignmentPayload(jsonData: data)
        let roundTrip = try JSONEncoder.assinafy.encode(buildAssignmentBody(decoded))
        XCTAssertEqual(try JSONDecoder.assinafy.decode(JSONValue.self, from: data),
                       try JSONDecoder.assinafy.decode(JSONValue.self, from: roundTrip))
        XCTAssertThrowsError(try CreateAssignmentPayload(jsonData: Data(#"{"method":"invalid","signers":[]}"#.utf8)))
    }

    func testQueryCompletionForwardsWireNamesAndUsesMainQueue() async {
        let mock = MockHTTPClient()
        mock.stubEnvelopeList([])
        let resource = AssignmentResource(http: mock, defaultAccountId: "account_1")
        let completed = expectation(description: "list completion")
        resource.list(query: ["page": "2", "per-page": "10"], accountId: nil) { items, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(items?.count, 0)
            XCTAssertNil(error)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(mock.lastRequest?.queryItems, [
            URLQueryItem(name: "page", value: "2"), URLQueryItem(name: "per-page", value: "10")
        ])
    }

    func testJSONCompletionValidatesBeforeSendingAndUsesMainQueue() async {
        let mock = MockHTTPClient()
        let resource = AssignmentResource(http: mock)
        let completed = expectation(description: "validation completion")
        resource.create(documentId: "doc_1", payloadJSON: Data(#"{"method":"virtual","signers":[{"id":" "}]}"#.utf8)) { assignment, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(assignment)
            XCTAssertTrue(error is ValidationError)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertTrue(mock.allRequests.isEmpty)
    }
    func testBlankTrustBoundaryValuesFailBeforeNetworkIO() async {
        let mock = MockHTTPClient()
        let documents = DocumentResource(http: mock, defaultAccountId: "account_1")
        let signers = SignerResource(http: mock, defaultAccountId: "account_1")
        await assertThrowsValidationError {
            _ = try await documents.rename(documentId: "doc_1", name: " ")
        }
        await assertThrowsValidationError {
            _ = try await documents.sendPublicSignToken(documentId: "doc_1", payload: SendTokenPayload(recipient: " ", channel: .whatsapp))
        }
        await assertThrowsValidationError {
            _ = try await documents.sendPublicSignToken(documentId: "doc_1", payload: SendTokenPayload(recipient: "invalid", channel: .email))
        }
        await assertThrowsValidationError {
            try await signers.verifyEmail(payload: VerifyEmailPayload(verificationCode: " ", signerAccessCode: "code_1"))
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
        XCTAssertThrowsError(try buildAssignmentBody(CreateAssignmentPayload(signers: [.id(" ")])))
    }

    func testPollingRejectsRoundedNanosecondOverflowBoundary() async {
        let mock = MockHTTPClient()
        let documents = DocumentResource(http: mock, defaultAccountId: "account_1")
        let boundary = Double(UInt64.max) / 1_000_000_000
        await assertThrowsValidationError {
            _ = try await documents.waitUntilReady(documentId: "doc_1", options:
                WaitUntilReadyOptions(maxWaitSeconds: boundary, pollIntervalSeconds: 1))
        }
        await assertThrowsValidationError {
            _ = try await documents.waitUntilReady(documentId: "doc_1", options:
                WaitUntilReadyOptions(maxWaitSeconds: 60, pollIntervalSeconds: boundary))
        }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

}
