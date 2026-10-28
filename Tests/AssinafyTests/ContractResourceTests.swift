import XCTest
@testable import Assinafy

final class ContractResourceTests: XCTestCase {
    private var mock: MockHTTPClient!
    private var contracts: ContractResource!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        contracts = ContractResource(http: mock, defaultAccountId: "account-1")
    }

    private let amendmentJSON = #"{"resource":"document_contract_amendment","document_id":"amendment-1","document_name":"Amendment.pdf","parent_document_id":"doc-1","relation_type":"amendment","number":1,"status":"applied","document_status":"certificated","apply_error":null,"currency":"BRL","terms":{"value":130000,"end_date":"2028-06-30","metadata":{"stage":"won"}},"changes":{"value":{"from":120000.5,"to":130000},"end_date":{"from":null,"to":"2028-06-30"},"term":{"from":1,"to":2}},"applied_at":"2027-05-12T18:20:00Z","created_at":"2027-05-10T15:00:00Z","updated_at":"2027-05-12T18:20:00Z"}"#

    private var contractJSON: String {
        #"{"resource":"document_contract","document_id":"doc-1","status":"active","counterparty_name":"Example Company","counterparty_taxpayer_id":"11222333000181","value":9999999999999.99,"currency":"BRL","start_date":"2026-11-01","end_date":"2027-10-31","auto_renew":true,"renewal_term_months":12,"notice_period_days":30,"term":2,"owner_id":"member-1","metadata":{"stage":"won"},"external_references":[{"system":"crm","id":"reference-1"}],"created_at":"2026-10-23T12:00:00Z","updated_at":"2027-05-12T18:20:00Z","document":{"id":"doc-1","name":"Contract.pdf","status":"certificated","created_at":"2026-10-23T12:00:00Z","updated_at":"2027-05-12T18:20:00Z","has_contract":true},"amendments":[\#(amendmentJSON)]}"#
    }

    private func stub(_ json: String, headers: [AnyHashable: Any] = [:]) {
        mock.stub(response: APIResponse(data: Data(#"{"status":200,"message":"","data":\#(json)}"#.utf8),
                                        headers: headers, statusCode: 200))
    }

    private func sentBody() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(mock.lastRequest?.body)) as? [String: Any])
    }

    func testListSendsAllFiltersAndReturnsPaginationAndExpandedDocument() async throws {
        stub("[\(contractJSON)]", headers: MockHTTPClient.paginationHeaders(currentPage: 2, perPage: 25, total: 30, pageCount: 2))
        let params = ContractListParams()
        params.status = "active,expired"; params.counterparty = "Example"; params.search = "Contract"
        params.endDateFrom = "2026-11-01"; params.endDateTo = "2027-10-31"; params.endingWithinDays = 30
        params.externalSystem = "crm"; params.externalId = "reference-1"; params.sort = "end_date"
        params.expand = "document"; params.page = 2; params.perPage = 25

        let result = try await contracts.list(params: params, accountId: "account-2")

        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/account-2/contracts")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: try XCTUnwrap(mock.lastRequest?.queryItems).map { ($0.name, $0.value!) }), [
            "status": "active,expired", "counterparty": "Example", "search": "Contract",
            "end_date_from": "2026-11-01", "end_date_to": "2027-10-31", "ending_within_days": "30",
            "external_system": "crm", "external_id": "reference-1", "sort": "end_date", "expand": "document",
            "page": "2", "per-page": "25",
        ])
        XCTAssertEqual(result.meta?.currentPage, 2)
        XCTAssertEqual(result.meta?.lastPage, 2)
        XCTAssertEqual(result.meta?.perPage, 25)
        XCTAssertEqual(result.meta?.total, 30)
        XCTAssertEqual(result.data.first?.document?.hasContract, true)
        XCTAssertEqual(result.data.first?.document?.id, "doc-1")
    }

    func testGetDecodesEveryContractAndAmendmentField() async throws {
        stub(contractJSON)
        let details = try await contracts.get(documentId: "doc-1")
        let contract = try XCTUnwrap(details.contract)
        XCTAssertNil(details.amendment)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/account-1/documents/doc-1/contract")
        XCTAssertEqual(mock.lastRequest?.method, .get)
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        XCTAssertEqual(contract.resource, "document_contract")
        XCTAssertEqual(contract.documentId, "doc-1")
        XCTAssertEqual(contract.status, "active")
        XCTAssertEqual(contract.counterpartyName, "Example Company")
        XCTAssertEqual(contract.counterpartyTaxpayerId, "11222333000181")
        XCTAssertEqual(contract.value?.stringValue, "9999999999999.99")
        XCTAssertEqual(contract.currency, "BRL")
        XCTAssertEqual(contract.startDate, "2026-11-01")
        XCTAssertEqual(contract.endDate, "2027-10-31")
        XCTAssertTrue(contract.autoRenew)
        XCTAssertEqual(contract.renewalTermMonths, 12)
        XCTAssertEqual(contract.noticePeriodDays, 30)
        XCTAssertEqual(contract.term, 2)
        XCTAssertEqual(contract.ownerId, "member-1")
        XCTAssertEqual(contract.metadata, ["stage": "won"])
        XCTAssertEqual(contract.externalReferences.first?.system, "crm")
        XCTAssertEqual(contract.externalReferences.first?.id, "reference-1")
        XCTAssertEqual(contract.createdAt, "2026-10-23T12:00:00Z")
        XCTAssertEqual(contract.updatedAt, "2027-05-12T18:20:00Z")

        let amendment = try XCTUnwrap(contract.amendments.first)
        XCTAssertEqual(amendment.resource, "document_contract_amendment")
        XCTAssertEqual(amendment.documentId, "amendment-1")
        XCTAssertEqual(amendment.documentName, "Amendment.pdf")
        XCTAssertEqual(amendment.parentDocumentId, "doc-1")
        XCTAssertEqual(amendment.relationType, "amendment")
        XCTAssertEqual(amendment.number, 1)
        XCTAssertEqual(amendment.status, "applied")
        XCTAssertEqual(amendment.documentStatus, "certificated")
        XCTAssertNil(amendment.applyError)
        XCTAssertEqual(amendment.currency, "BRL")
        XCTAssertEqual(amendment.terms?["value"] as? Int64, 130000)
        XCTAssertEqual(amendment.terms?["metadata"] as? [String: String], ["stage": "won"])
        XCTAssertNotNil(amendment.termsJSON)
        XCTAssertNotNil(amendment.changesJSON)
        let endDateChange = try XCTUnwrap(amendment.changes?["end_date"] as? [String: Any])
        XCTAssertTrue(endDateChange["from"] is NSNull)
        XCTAssertEqual(endDateChange["to"] as? String, "2028-06-30")
        XCTAssertEqual(amendment.appliedAt, "2027-05-12T18:20:00Z")
        XCTAssertEqual(amendment.createdAt, "2027-05-10T15:00:00Z")
        XCTAssertEqual(amendment.updatedAt, "2027-05-12T18:20:00Z")
    }

    func testGetRecognizesAmendmentsWithAndWithoutDiscriminator() async throws {
        for body in [amendmentJSON, #"{"parent_document_id":"doc-1","status":"pending","terms":null,"changes":null,"apply_error":"Earlier instrument pending"}"#] {
            stub(body)
            let result = try await contracts.get(documentId: "amendment-1")
            XCTAssertNil(result.contract)
            XCTAssertEqual(result.amendment?.parentDocumentId, "doc-1")
        }
        let pending = try JSONDecoder().decode(DocumentContractAmendment.self, from: Data(#"{"status":"pending","number":null,"terms":null,"changes":null}"#.utf8))
        XCTAssertNil(pending.number)
        XCTAssertNil(pending.terms)
        XCTAssertNil(pending.changes)
        XCTAssertNil(pending.appliedAt)
        XCTAssertEqual(pending.termsJSON, JSONValue(.null))
    }

    func testOptionalResponseFieldsHaveDefensiveDefaults() throws {
        let contract = try JSONDecoder().decode(DocumentContract.self, from: Data("{}".utf8))
        XCTAssertNil(contract.documentId)
        XCTAssertNil(contract.value)
        XCTAssertNil(contract.term)
        XCTAssertFalse(contract.autoRenew)
        XCTAssertTrue(contract.externalReferences.isEmpty)
        XCTAssertTrue(contract.amendments.isEmpty)
        let future = try JSONDecoder().decode(DocumentContract.self, from: Data(#"{"status":"future_status"}"#.utf8))
        XCTAssertEqual(future.status, "future_status")
    }

    func testUpdateSendsEveryFieldAndExactDecimal() async throws {
        stub(contractJSON)
        let payload = UpdateContractPayload(
            status: "active", counterpartyName: "Example Company", counterpartyTaxpayerId: "11.222.333/0001-81",
            value: NSDecimalNumber(string: "9999999999999.99"), currency: "BRL", startDate: "2026-11-01",
            endDate: "2027-10-31", autoRenew: false, renewalTermMonths: 12, noticePeriodDays: 0,
            ownerId: "member-1", metadata: ["stage": "won"],
            externalReferences: [ContractExternalReference(system: "crm", id: "reference-1")],
            parentDocumentId: "parent-1", relationType: "amendment", updatedAt: "2026-10-23T12:00:00Z"
        )
        _ = try await contracts.update(documentId: "doc-1", payload: payload)
        XCTAssertEqual(mock.lastRequest?.method, .put)
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/account-1/documents/doc-1/contract")
        XCTAssertEqual(mock.lastRequest?.credential, .workspace)
        let body = try sentBody()
        XCTAssertEqual(body.count, 16)
        XCTAssertEqual(body["status"] as? String, "active")
        XCTAssertEqual(body["counterparty_name"] as? String, "Example Company")
        XCTAssertEqual(body["counterparty_taxpayer_id"] as? String, "11.222.333/0001-81")
        XCTAssertEqual(body["currency"] as? String, "BRL")
        XCTAssertEqual(body["start_date"] as? String, "2026-11-01")
        XCTAssertEqual(body["end_date"] as? String, "2027-10-31")
        XCTAssertEqual(body["auto_renew"] as? Bool, false)
        XCTAssertEqual(body["renewal_term_months"] as? Int, 12)
        XCTAssertEqual(body["notice_period_days"] as? Int, 0)
        XCTAssertEqual(body["owner_id"] as? String, "member-1")
        XCTAssertEqual(body["metadata"] as? [String: String], ["stage": "won"])
        XCTAssertEqual(body["external_references"] as? [[String: String]], [["system": "crm", "id": "reference-1"]])
        XCTAssertEqual(body["parent_document_id"] as? String, "parent-1")
        XCTAssertEqual(body["relation_type"] as? String, "amendment")
        XCTAssertEqual(body["updated_at"] as? String, "2026-10-23T12:00:00Z")
        XCTAssertTrue(String(decoding: try XCTUnwrap(mock.lastRequest?.body), as: UTF8.self).contains("\"value\":9999999999999.99"))
    }

    func testUpdateDistinguishesOmissionNullAndEmptyCollections() async throws {
        stub(contractJSON)
        _ = try await contracts.update(documentId: "doc-1", payload: UpdateContractPayload(noticePeriodDays: 60, clearFields: ["counterparty_name"]))
        var body = try sentBody()
        XCTAssertEqual(body.count, 2)
        XCTAssertTrue(body["counterparty_name"] is NSNull)
        XCTAssertNil(body["value"])
        stub(contractJSON)
        _ = try await contracts.update(documentId: "doc-1", payload: UpdateContractPayload(metadata: [:], externalReferences: []))
        body = try sentBody()
        XCTAssertEqual(body["metadata"] as? [String: String], [:])
        XCTAssertEqual((body["external_references"] as? [Any])?.count, 0)

        let fields = UpdateContractPayload.CodingKeys.allCases.filter { $0 != .status && $0 != .relationType }.map(\.rawValue)
        let nulls = try JSONSerialization.jsonObject(with: JSONEncoder().encode(UpdateContractPayload(clearFields: fields))) as? [String: Any]
        XCTAssertEqual(nulls?.count, fields.count)
        for field in fields { XCTAssertTrue(nulls?[field] is NSNull, field) }
    }

    func testUpdateReturnsAmendmentAndEncodesUnlink() async throws {
        stub(amendmentJSON)
        let linked = try await contracts.update(documentId: "amendment-1", payload: UpdateContractPayload(parentDocumentId: "doc-1", relationType: "amendment"))
        XCTAssertEqual(linked.amendment?.documentId, "amendment-1")
        let unlink = try JSONSerialization.jsonObject(with: JSONEncoder().encode(UpdateContractPayload(clearFields: ["parent_document_id"]))) as? [String: Any]
        XCTAssertTrue(unlink?["parent_document_id"] is NSNull)
    }

    func testRelatedRenewAndTerminateRoutesAndBodies() async throws {
        stub(contractJSON)
        let family = try await contracts.related(documentId: "amendment-1")
        XCTAssertEqual(family.documentId, "doc-1")
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/account-1/documents/amendment-1/contract/related")
        XCTAssertEqual(mock.lastRequest?.method, .get)
        stub(contractJSON)
        _ = try await contracts.renew(documentId: "doc-1", payload: RenewContractPayload(term: 2, value: NSDecimalNumber(string: "1200.50"), updatedAt: "2026-10-23T12:00:00Z"))
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/account-1/documents/doc-1/contract/renew")
        XCTAssertEqual(mock.lastRequest?.method, .post)
        var body = try sentBody()
        XCTAssertEqual(body["term"] as? Int, 2)
        XCTAssertEqual(body["updated_at"] as? String, "2026-10-23T12:00:00Z")
        XCTAssertNil(body["end_date"])
        stub(contractJSON)
        _ = try await contracts.renew(documentId: "doc-1", payload: RenewContractPayload(endDate: "2029-01-01", clearsValue: true))
        body = try sentBody()
        XCTAssertEqual(body["end_date"] as? String, "2029-01-01")
        XCTAssertTrue(body["value"] is NSNull)
        XCTAssertNil(body["term"])
        stub(contractJSON)
        _ = try await contracts.terminate(documentId: "doc-1", payload: TerminateContractPayload(reason: "Supplier replaced", updatedAt: "2026-10-23T12:00:00Z"))
        XCTAssertEqual(mock.lastRequest?.path, "/accounts/account-1/documents/doc-1/contract/terminate")
        XCTAssertEqual(mock.lastRequest?.method, .post)
        body = try sentBody()
        XCTAssertEqual(body["reason"] as? String, "Supplier replaced")
        XCTAssertEqual(body["updated_at"] as? String, "2026-10-23T12:00:00Z")
        stub(contractJSON)
        _ = try await contracts.terminate(documentId: "doc-1")
        XCTAssertTrue(try sentBody().isEmpty)
        XCTAssertTrue(mock.allRequests.allSatisfy { $0.credential == .workspace })
    }

    func testInvalidPayloadsAndPathsNeverSendRequests() async {
        for payload in [UpdateContractPayload(), UpdateContractPayload(clearFields: ["unknown"]),
                        UpdateContractPayload(clearFields: ["status"]), UpdateContractPayload(clearFields: ["relation_type"]),
                        UpdateContractPayload(value: 1, clearFields: ["value"]), UpdateContractPayload(value: .notANumber),
                        UpdateContractPayload(renewalTermMonths: 1.5), UpdateContractPayload(noticePeriodDays: -1)] {
            await assertThrowsValidationError { _ = try await self.contracts.update(documentId: "doc-1", payload: payload) }
        }
        for payload in [RenewContractPayload(), RenewContractPayload(endDate: " "), RenewContractPayload(term: 0),
                        RenewContractPayload(term: 1.5), RenewContractPayload(term: 1, value: 1, clearsValue: true)] {
            await assertThrowsValidationError { _ = try await self.contracts.renew(documentId: "doc-1", payload: payload) }
        }
        await assertThrowsValidationError { _ = try await self.contracts.terminate(documentId: "doc-1", payload: TerminateContractPayload(reason: String(repeating: "a", count: 501))) }
        for id in ["", " ", "..", "a/b"] {
            await assertThrowsValidationError { _ = try await self.contracts.get(documentId: id) }
            await assertThrowsValidationError { _ = try await self.contracts.related(documentId: id) }
            await assertThrowsValidationError { _ = try await self.contracts.list(accountId: id) }
        }
        let params = ContractListParams()
        params.endingWithinDays = 3651
        await assertThrowsValidationError { _ = try await self.contracts.list(params: params) }
        params.endingWithinDays = nil; params.perPage = 101
        await assertThrowsValidationError { _ = try await self.contracts.list(params: params) }
        XCTAssertTrue(mock.allRequests.isEmpty)
    }

    func testConcurrentChangePropagatesWithoutRetry() async {
        let calls: [() async throws -> Void] = [
            { _ = try await self.contracts.update(documentId: "doc-1", payload: UpdateContractPayload(status: "active", updatedAt: "2026-10-23T12:00:00Z")) },
            { _ = try await self.contracts.renew(documentId: "doc-1", payload: RenewContractPayload(term: 1, updatedAt: "2026-10-23T12:00:00Z")) },
            { _ = try await self.contracts.terminate(documentId: "doc-1", payload: TerminateContractPayload(updatedAt: "2026-10-23T12:00:00Z")) },
        ]
        for call in calls {
            mock.stub(error: APIError(statusCode: 409, message: "Contract changed", responseData: ["code": "ContractChanged"]))
            do { try await call(); XCTFail("Expected conflict") }
            catch let error as APIError {
                XCTAssertEqual(error.statusCode, 409)
                XCTAssertEqual((error.responseData as? [String: String])?["code"], "ContractChanged")
            } catch { XCTFail("Expected APIError, got \(error)") }
        }
        XCTAssertEqual(mock.allRequests.count, 3)
    }

    func testDocumentContractFlagPreservesTrueFalseAndAbsence() throws {
        for flag: Bool? in [true, false, nil] {
            var object: [String: Any] = ["id": "doc-1", "name": "Contract.pdf", "status": "certificated",
                                       "created_at": "2026-10-23T12:00:00Z", "updated_at": "2026-10-23T12:00:00Z",
                                       "artifacts": ["original": "https://example.invalid/contract.pdf"]]
            object["has_contract"] = flag
            let data = try JSONSerialization.data(withJSONObject: object)
            let decoder = JSONDecoder()
            XCTAssertEqual(try decoder.decode(DocumentDetails.self, from: data).hasContract?.boolValue, flag)
            XCTAssertEqual(try decoder.decode(DocumentListItem.self, from: data).hasContract?.boolValue, flag)
            XCTAssertEqual(try decoder.decode(DocumentUploadResponse.self, from: data).hasContract?.boolValue, flag)
            XCTAssertEqual(try decoder.decode(PublicDocumentInfo.self, from: data).hasContract?.boolValue, flag)
        }
    }

    func testEveryCompletionDeliversOnMainQueue() async {
        let done = expectation(description: "six contract completions")
        done.expectedFulfillmentCount = 6
        func resource(list: Bool = false) -> ContractResource {
            let transport = MockHTTPClient()
            if list { transport.stubEnvelopeList([["document_id": "doc-1"]]) }
            else { transport.stubEnvelope(["document_id": "doc-1"]) }
            return ContractResource(http: transport, defaultAccountId: "account-1")
        }
        resource(list: true).list(params: ContractListParams(), accountId: nil) { values, error in
            XCTAssertTrue(Thread.isMainThread); XCTAssertNil(error); XCTAssertEqual(values?.first?.documentId, "doc-1"); done.fulfill()
        }
        resource().get(documentId: "doc-1", accountId: nil) { details, error in
            XCTAssertTrue(Thread.isMainThread); XCTAssertNil(error); XCTAssertEqual(details?.contract?.documentId, "doc-1"); done.fulfill()
        }
        resource().update(documentId: "doc-1", payload: UpdateContractPayload(status: "active"), accountId: nil) { details, error in
            XCTAssertTrue(Thread.isMainThread); XCTAssertNil(error); XCTAssertEqual(details?.contract?.documentId, "doc-1"); done.fulfill()
        }
        resource().related(documentId: "doc-1", accountId: nil) { value, error in
            XCTAssertTrue(Thread.isMainThread); XCTAssertNil(error); XCTAssertEqual(value?.documentId, "doc-1"); done.fulfill()
        }
        resource().renew(documentId: "doc-1", payload: RenewContractPayload(term: 1), accountId: nil) { value, error in
            XCTAssertTrue(Thread.isMainThread); XCTAssertNil(error); XCTAssertEqual(value?.documentId, "doc-1"); done.fulfill()
        }
        resource().terminate(documentId: "doc-1", payload: TerminateContractPayload(), accountId: nil) { value, error in
            XCTAssertTrue(Thread.isMainThread); XCTAssertNil(error); XCTAssertEqual(value?.documentId, "doc-1"); done.fulfill()
        }
        await fulfillment(of: [done], timeout: 2)
    }
}
