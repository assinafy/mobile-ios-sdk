import XCTest
@testable import Assinafy

final class IdentityVerificationTests: XCTestCase {
    private let mock = MockHTTPClient()
    private let reviewPath = "/documents/doc/assignments/assignment/signers/signer/identity-verification"

    func testBiometricAssignmentAndTemplateInputsEncodeAPIMethod() throws {
        let assignment = CreateAssignmentPayload(signers: [
            .descriptor(id: "signer", verificationMethod: "IdDocumentFaceMatchBasic", notificationMethods: ["Email"]),
        ])
        let body = try JSONEncoder.assinafy.encode(buildAssignmentBody(assignment))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let signer = try XCTUnwrap((json["signers"] as? [[String: Any]])?.first)
        XCTAssertEqual(signer["verification_method"] as? String, "IdDocumentFaceMatchBasic")
        XCTAssertEqual(signer["notification_methods"] as? [String], ["Email"])
        let templateSigner = TemplateSigner(roleId: "role", id: "signer", verificationMethod: "IdDocumentFaceMatchBasic", notificationMethods: ["Whatsapp"])
        let template = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder.assinafy.encode(templateSigner)) as? [String: Any])
        XCTAssertEqual(template["verification_method"] as? String, "IdDocumentFaceMatchBasic")
        XCTAssertEqual(template["notification_methods"] as? [String], ["Whatsapp"])
    }

    func testSignerStatusPreservesCaptureFragmentAndOptionalFields() async throws {
        mock.stubEnvelope(["can_start": false, "status": "Pending",
                           "url": "https://verify.example.invalid/c/session#t=synthetic"])
        let state = try await SignerResource(http: mock).identityVerification(signerAccessCode: "code")
        XCTAssertEqual(state.status, "Pending")
        XCTAssertFalse(state.canStart)
        XCTAssertEqual(state.url, "https://verify.example.invalid/c/session#t=synthetic")
        XCTAssertNil(state.expiresAt)
        XCTAssertNil(state.completedAt)
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/signers/identity-verification")
        XCTAssertEqual(mock.lastRequest?.queryItems, [URLQueryItem(name: "signer-access-code", value: "code")])
    }

    func testStartSendsOnlyExplicitConsent() async throws {
        mock.stubEnvelope(["id": "session", "url": "https://verify.example.invalid/c/session#t=synthetic"])
        let session = try await SignerResource(http: mock).startIdentityVerification(
            signerAccessCode: "code", payload: StartIdentityVerificationPayload(consent: true))
        XCTAssertEqual(session.id, "session")
        XCTAssertTrue(session.url.hasSuffix("#t=synthetic"))
        XCTAssertNil(session.expiresAt)
        XCTAssertEqual(mock.lastRequest?.method, .post)
        XCTAssertEqual(mock.lastRequest?.path, "/signers/identity-verification")
        XCTAssertEqual(mock.lastRequest?.queryItems, [URLQueryItem(name: "signer-access-code", value: "code")])
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(mock.lastRequest?.body)) as? [String: Bool])
        XCTAssertEqual(body, ["consent": true])
    }

    func testMissingConsentAndUnsafeSignerCodesFailBeforeIO() async {
        let signers = SignerResource(http: mock)
        for code in ["", " ", "../code"] {
            do {
                _ = try await signers.identityVerification(signerAccessCode: code)
                XCTFail("Expected ValidationError")
            } catch { XCTAssertTrue(error is ValidationError) }
            do {
                _ = try await signers.startIdentityVerification(
                    signerAccessCode: code, payload: StartIdentityVerificationPayload(consent: true))
                XCTFail("Expected ValidationError")
            } catch { XCTAssertTrue(error is ValidationError) }
        }
        do {
            _ = try await signers.startIdentityVerification(
                signerAccessCode: "code", payload: StartIdentityVerificationPayload(consent: false))
            XCTFail("Expected ValidationError")
        } catch { XCTAssertTrue(error is ValidationError) }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testWorkspaceReviewAndEveryImageRoute() async throws {
        let assignments = AssignmentResource(http: mock)
        mock.stubEnvelope(["id": "review", "status": "InReview", "images": ["face"]])
        let review = try await assignments.identityReview(documentId: "doc", assignmentId: "assignment", signerId: "signer")
        XCTAssertEqual(review.status, "InReview")
        XCTAssertEqual(review.images, ["face"])
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, reviewPath)
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        XCTAssertNil(mock.lastRequest?.queryItems)
        for name in ["document_front", "document_back", "document_pdf", "face"] {
            mock.stub(response: APIResponse(data: Data([1, 2, 3]), statusCode: 200))
            let bytes = try await assignments.downloadIdentityReviewImage(
                documentId: "doc", assignmentId: "assignment", signerId: "signer", name: name)
            XCTAssertEqual(bytes, Data([1, 2, 3]))
            XCTAssertEqual(mock.lastRequest?.path, reviewPath + "/images/" + name)
            XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        }
    }

    func testReviewDecisionBodyAndValidation() async throws {
        let assignments = AssignmentResource(http: mock)
        for decision in ["Approved", "Rejected"] {
            mock.stubEnvelope(["status": decision])
            let result = try await assignments.reviewIdentityVerification(
                documentId: "doc", assignmentId: "assignment", signerId: "signer",
                payload: ReviewIdentityVerificationPayload(decision: decision, note: "Reviewed"))
            XCTAssertEqual(result.status, decision)
            XCTAssertEqual(mock.lastRequest?.method, .post)
            XCTAssertEqual(mock.lastRequest?.path, reviewPath + "/review")
            XCTAssertEqual(mock.lastRequest?.credential, .workspace)
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(mock.lastRequest?.body)) as? [String: String])
            XCTAssertEqual(body, ["decision": decision, "note": "Reviewed"])
        }
        let count = mock.allRequests.count
        for payload in [ReviewIdentityVerificationPayload(decision: "approved"),
                        ReviewIdentityVerificationPayload(decision: "Approved", note: String(repeating: "a", count: 2001))] {
            do {
                _ = try await assignments.reviewIdentityVerification(
                    documentId: "doc", assignmentId: "assignment", signerId: "signer", payload: payload)
                XCTFail("Expected ValidationError")
            } catch { XCTAssertTrue(error is ValidationError) }
        }
        XCTAssertEqual(mock.allRequests.count, count)
    }

    func testUnsafeReviewPathsAndImageNamesFailBeforeIO() async {
        let assignments = AssignmentResource(http: mock)
        do {
            _ = try await assignments.identityReview(documentId: "../doc", assignmentId: "assignment", signerId: "signer")
            XCTFail("Expected ValidationError")
        } catch { XCTAssertTrue(error is ValidationError) }
        do {
            _ = try await assignments.downloadIdentityReviewImage(
                documentId: "doc", assignmentId: "assignment", signerId: "signer", name: "../face")
            XCTFail("Expected ValidationError")
        } catch { XCTAssertTrue(error is ValidationError) }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testReviewDefaultsAndNullEvidenceDecode() throws {
        let review = try JSONDecoder.assinafy.decode(SignerIdentityReview.self, from: Data(
            #"{"expected":null,"document":null,"matches":null,"reviewed_by":null}"#.utf8))
        XCTAssertEqual(review.reasonCodes.count, 0)
        XCTAssertEqual(review.checks.count, 0)
        XCTAssertFalse(review.evidenceAvailable)
        XCTAssertNil(review.expected)
        XCTAssertNil(review.reviewedBy)
        let state = try JSONDecoder.assinafy.decode(IdentityVerificationState.self, from: Data("{}".utf8))
        XCTAssertFalse(state.canStart)
        XCTAssertNil(state.status)
    }

    func testPendingIdentityReviewIsReadyAndSignerFieldsDecode() async throws {
        mock.stubEnvelope(["id": "doc", "name": "contract.pdf", "status": "pending_identity_review", "artifacts": ["original": "https://example.invalid/original.pdf"],
                           "created_at": "2026-10-16", "updated_at": "2026-10-16"])
        let document = try await DocumentResource(http: mock).waitUntilReady(documentId: "doc")
        XCTAssertEqual(document.status, .unknown)
        XCTAssertEqual(document.statusString, "pending_identity_review")
        let data = Data(#"{"id":"s","full_name":"Signer","verification_method":"IdDocumentFaceMatchBasic","identity_verification_status":"InReview"}"#.utf8)
        let signer = try JSONDecoder.assinafy.decode(Signer.self, from: data)
        XCTAssertEqual(signer.verificationMethod, "IdDocumentFaceMatchBasic")
        XCTAssertNil(signer.verification)
        XCTAssertEqual(signer.identityVerificationStatus, "InReview")
        XCTAssertEqual(try JSONDecoder.assinafy.decode(SignerSelfInfo.self, from: data).verificationMethod, "IdDocumentFaceMatchBasic")
    }

    func testEveryIdentityCompletionUsesMainQueueAndForwardsArguments() async {
        let signers = SignerResource(http: mock)
        mock.stubEnvelope(["id": "session", "url": "https://verify.example.invalid/c/session#t=synthetic"])
        let start = expectation(description: "start")
        signers.startIdentityVerification(signerAccessCode: "code", payload: StartIdentityVerificationPayload(consent: true)) { session, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(session?.id, "session")
            XCTAssertNil(error)
            start.fulfill()
        }
        await fulfillment(of: [start], timeout: 2)
        let assignments = AssignmentResource(http: mock)
        mock.stubEnvelope(["id": "review"])
        let get = expectation(description: "review")
        assignments.identityReview(documentId: "doc", assignmentId: "assignment", signerId: "signer") { review, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(review?.id, "review")
            XCTAssertNil(error)
            get.fulfill()
        }
        await fulfillment(of: [get], timeout: 2)
        mock.stub(response: APIResponse(data: Data([1]), statusCode: 200))
        let image = expectation(description: "image")
        assignments.downloadIdentityReviewImage(documentId: "doc", assignmentId: "assignment", signerId: "signer", name: "face") { data, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(data, Data([1]))
            XCTAssertNil(error)
            image.fulfill()
        }
        await fulfillment(of: [image], timeout: 2)
        mock.stubEnvelope(["status": "Approved"])
        let decide = expectation(description: "decision")
        assignments.reviewIdentityVerification(
            documentId: "doc", assignmentId: "assignment", signerId: "signer",
            payload: ReviewIdentityVerificationPayload(decision: "Approved")) { review, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(review?.status, "Approved")
            XCTAssertNil(error)
            decide.fulfill()
        }
        await fulfillment(of: [decide], timeout: 2)
        XCTAssertEqual(mock.allRequests.map(\.path), [
            "/signers/identity-verification", reviewPath, reviewPath + "/images/face", reviewPath + "/review",
        ])
    }

    func testExplicitCompletionDeliversOnMainQueue() {
        mock.stubEnvelope(["can_start": true])
        let done = expectation(description: "completion")
        SignerResource(http: mock).identityVerification(signerAccessCode: "code") { state, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(state?.canStart == true)
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
    }
}
