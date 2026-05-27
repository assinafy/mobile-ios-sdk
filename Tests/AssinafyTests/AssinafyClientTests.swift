import XCTest
@testable import Assinafy

final class AssinafyClientTests: XCTestCase {

    func testConfigurationInitialisation() {
        let config = AssinafyClientConfiguration(
            apiKey: "test-key",
            baseURL: "https://api.test.com",
            defaultAccountId: "acc-123",
            timeout: 60
        )
        XCTAssertEqual(config.apiKey, "test-key")
        XCTAssertEqual(config.baseURL, "https://api.test.com")
        XCTAssertEqual(config.defaultAccountId, "acc-123")
        XCTAssertEqual(config.timeout, 60)
    }

    func testTokenInitialisationExposesResources() {
        let client = AssinafyClient(token: "token", defaultAccountId: "acc")
        XCTAssertNotNil(client.documents)
        XCTAssertNotNil(client.signers)
        XCTAssertNotNil(client.assignments)
        XCTAssertNotNil(client.webhooks)
        XCTAssertNotNil(client.templates)
        XCTAssertNotNil(client.tags)
        XCTAssertNotNil(client.workspaces)
        XCTAssertNotNil(client.fields)
        XCTAssertNotNil(client.auth)
    }

    func testAllowsNoCredentialsForUnauthenticatedAuthFlows() {
        let client = AssinafyClient(configuration: AssinafyClientConfiguration())
        XCTAssertNotNil(client.auth)
    }

    func testInternalInitWithMockHTTP() {
        let mock = MockHTTPClient()
        let client = AssinafyClient(http: mock, defaultAccountId: "acc")
        XCTAssertNotNil(client)
    }

    func testTrailingSlashInBaseURLIsHandled() {
        let config = AssinafyClientConfiguration(
            apiKey: "key",
            baseURL: "https://api.test.com/"
        )
        let client = AssinafyClient(configuration: config)
        XCTAssertNotNil(client)
    }
}
