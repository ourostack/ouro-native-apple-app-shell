import Foundation
import XCTest
@testable import OuroAppShellCore

final class ReleaseUpdateTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        URLProtocol.registerClass(RecordingURLProtocol.self)
    }

    override class func tearDown() {
        URLProtocol.unregisterClass(RecordingURLProtocol.self)
        super.tearDown()
    }

    override func tearDown() {
        RecordingURLProtocol.reset()
        super.tearDown()
    }

    private var mdIdentity: AppShellIdentity {
        AppShellIdentity(
            appName: "Ouro MD",
            bundleIdentifier: "org.ourostack.ouro-md",
            repository: "ourostack/ouro-md",
            version: "0.9.22",
            userAgent: "OuroMD/0.9.22"
        )
    }

    private var workbenchIdentity: AppShellIdentity {
        AppShellIdentity(
            appName: "Ouro Workbench",
            bundleIdentifier: "com.ourostack.workbench",
            repository: "ourostack/ouro-workbench",
            version: "0.1.155",
            build: "238",
            userAgent: "OuroWorkbench/0.1.155"
        )
    }

    func testConfigurationDerivesDefaultsAndRequestHeaders() throws {
        let configuration = ReleaseUpdateConfiguration(identity: mdIdentity, timeout: 7)
        let defaultLoaderChecker = ReleaseUpdateChecker(configuration: configuration)
        let request = ReleaseUpdateChecker.request(for: configuration)

        XCTAssertEqual(defaultLoaderChecker.configuration, configuration)
        XCTAssertEqual(configuration.repository, "ourostack/ouro-md")
        XCTAssertEqual(configuration.currentVersion, "0.9.22")
        XCTAssertNil(configuration.currentBuild)
        XCTAssertEqual(configuration.releasesURL.absoluteString, "https://api.github.com/repos/ourostack/ouro-md/releases?per_page=10")
        XCTAssertEqual(request.url, configuration.releasesURL)
        XCTAssertEqual(request.timeoutInterval, 7)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "OuroMD/0.9.22")
    }

    func testSnapshotReportsStableUpdateWithPublishedMetadataAndInstallableAssets() throws {
        let data = Data("""
        [
          {
            "tag_name": "v0.10.0",
            "html_url": "https://github.com/ourostack/ouro-md/releases/tag/v0.10.0",
            "published_at": "2026-06-22T19:00:06Z",
            "body": "## Highlights\\n- Better update clarity",
            "draft": false,
            "prerelease": false,
            "assets": [
              {"name": "Ouro-MD-0.10.0.zip", "browser_download_url": "https://example.test/app.zip", "size": 100},
              {"name": "Ouro-MD-0.10.0.manifest.json", "browser_download_url": "https://example.test/manifest.json", "size": 50}
            ]
          }
        ]
        """.utf8)

        let snapshot = try ReleaseUpdateChecker.snapshot(from: data, currentVersion: "0.9.0")

        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.latestVersion, "0.10.0")
        XCTAssertNil(snapshot.latestBuild)
        XCTAssertEqual(snapshot.tagName, "v0.10.0")
        XCTAssertEqual(snapshot.htmlURL, "https://github.com/ourostack/ouro-md/releases/tag/v0.10.0")
        XCTAssertEqual(snapshot.publishedAt, "2026-06-22T19:00:06Z")
        XCTAssertEqual(snapshot.body, "## Highlights\n- Better update clarity")
        XCTAssertEqual(snapshot.detail, "Version 0.10.0 is available.")
        XCTAssertEqual(snapshot.releaseLabel, "0.10.0")
        XCTAssertEqual(snapshot.currentReleaseLabel, "Version 0.9.0")
        XCTAssertEqual(snapshot.currentReleaseLabelForPrompt, "0.9.0")
        XCTAssertEqual(snapshot.latestReleaseLabel, "Version 0.10.0")
        XCTAssertEqual(snapshot.latestReleaseLabelForPrompt, "0.10.0")
        XCTAssertTrue(snapshot.hasInstallableAssets)
        XCTAssertEqual(snapshot.installableAssets.count, 2)
    }

    func testSnapshotSkipsPrereleasesByDefaultAndCanIncludeThem() throws {
        let data = Data("""
        [
          {"tag_name":"v9.0.0-beta.1","html_url":"https://example.test/beta","draft":false,"prerelease":true,"assets":[]},
          {"tag_name":"v0.10.0","html_url":"https://example.test/stable","draft":false,"prerelease":false,"assets":[]}
        ]
        """.utf8)

        let stable = try ReleaseUpdateChecker.snapshot(from: data, currentVersion: "0.9.0")
        let prerelease = try ReleaseUpdateChecker.snapshot(
            from: data,
            currentVersion: "0.9.0",
            includePrereleases: true
        )

        XCTAssertEqual(stable.latestVersion, "0.10.0")
        XCTAssertEqual(stable.tagName, "v0.10.0")
        XCTAssertEqual(prerelease.latestVersion, "9.0.0-beta.1")
        XCTAssertEqual(prerelease.tagName, "v9.0.0-beta.1")
    }

    func testSnapshotTreatsStableSameCoreReleaseAsNewerThanCurrentPrerelease() throws {
        let data = Data("""
        [
          {"tag_name":"v1.2.3-beta.1","html_url":"https://example.test/beta","draft":false,"prerelease":true,"assets":[]},
          {"tag_name":"v1.2.3","html_url":"https://example.test/stable","draft":false,"prerelease":false,"assets":[]}
        ]
        """.utf8)

        let snapshot = try ReleaseUpdateChecker.snapshot(
            from: data,
            currentVersion: "1.2.3-beta.1",
            includePrereleases: true
        )

        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.latestVersion, "1.2.3")
        XCTAssertEqual(snapshot.tagName, "v1.2.3")
        XCTAssertEqual(snapshot.htmlURL, "https://example.test/stable")
    }

    func testSnapshotSelectsStableSameCoreReleaseInsteadOfPrereleaseAPIOrder() throws {
        let data = Data("""
        [
          {"tag_name":"v1.2.3-beta.2","html_url":"https://example.test/beta2","draft":false,"prerelease":true,"assets":[]},
          {"tag_name":"v1.2.3","html_url":"https://example.test/stable","draft":false,"prerelease":false,"assets":[]},
          {"tag_name":"v1.2.3-beta.11","html_url":"https://example.test/beta11","draft":false,"prerelease":true,"assets":[]}
        ]
        """.utf8)

        let snapshot = try ReleaseUpdateChecker.snapshot(
            from: data,
            currentVersion: "1.2.3-beta.1",
            includePrereleases: true
        )

        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.latestVersion, "1.2.3")
        XCTAssertEqual(snapshot.tagName, "v1.2.3")
        XCTAssertEqual(snapshot.htmlURL, "https://example.test/stable")
    }

    func testSnapshotSelectsHighestComparableStableReleaseInsteadOfAPIOrder() throws {
        let data = Data("""
        [
          {"tag_name":"v0.9.1","html_url":"https://example.test/older","draft":false,"prerelease":false,"assets":[]},
          {"tag_name":"v0.10.0","html_url":"https://example.test/newer","draft":false,"prerelease":false,"assets":[]}
        ]
        """.utf8)

        let snapshot = try ReleaseUpdateChecker.snapshot(from: data, currentVersion: "0.9.0")

        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.latestVersion, "0.10.0")
        XCTAssertEqual(snapshot.tagName, "v0.10.0")
        XCTAssertEqual(snapshot.htmlURL, "https://example.test/newer")
    }

    func testSnapshotSkipsMalformedEligibleReleaseWhenComparableLaterReleaseExists() throws {
        let data = Data("""
        [
          {"tag_name":"banana","html_url":"https://example.test/banana","draft":false,"prerelease":false,"assets":[]},
          {"tag_name":"v0.10.0","html_url":"https://example.test/newer","draft":false,"prerelease":false,"assets":[]}
        ]
        """.utf8)

        let snapshot = try ReleaseUpdateChecker.snapshot(from: data, currentVersion: "0.9.0")

        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.latestVersion, "0.10.0")
        XCTAssertEqual(snapshot.tagName, "v0.10.0")
        XCTAssertEqual(snapshot.detail, "Version 0.10.0 is available.")
    }

    func testSnapshotKeepsFirstComparableReleaseWhenVersionAndBuildAreTied() throws {
        let data = Data("""
        [
          {"tag_name":"v0.10.0","html_url":"https://example.test/first","draft":false,"prerelease":false,"assets":[]},
          {"tag_name":"v0.10.0","html_url":"https://example.test/second","draft":false,"prerelease":false,"assets":[]}
        ]
        """.utf8)

        let snapshot = try ReleaseUpdateChecker.snapshot(from: data, currentVersion: "0.9.0")

        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.latestVersion, "0.10.0")
        XCTAssertNil(snapshot.latestBuild)
        XCTAssertEqual(snapshot.htmlURL, "https://example.test/first")
    }

    func testSnapshotReportsCurrentUnavailableAndNoPublishedRelease() throws {
        let currentData = Data("""
        [{"tag_name":"v0.9.0","html_url":"https://example.test/current","draft":false,"prerelease":false,"assets":[]}]
        """.utf8)
        let invalidData = Data("""
        [{"tag_name":"banana","html_url":"https://example.test/banana","draft":false,"prerelease":false,"assets":[]}]
        """.utf8)
        let draftData = Data("""
        [{"tag_name":"v1.0.0","html_url":"https://example.test/draft","draft":true,"prerelease":false,"assets":[]}]
        """.utf8)

        let current = try ReleaseUpdateChecker.snapshot(from: currentData, currentVersion: "0.9.0")
        XCTAssertEqual(current.status, .current)
        XCTAssertEqual(current.detail, "Version 0.9.0 is current.")

        let invalid = try ReleaseUpdateChecker.snapshot(from: invalidData, currentVersion: "0.9.0")
        XCTAssertEqual(invalid.status, .unavailable)
        XCTAssertEqual(invalid.latestVersion, "banana")
        XCTAssertEqual(invalid.detail, "Latest release banana could not be compared to 0.9.0.")

        let none = try ReleaseUpdateChecker.snapshot(from: draftData, currentVersion: "0.9.0")
        XCTAssertEqual(none.status, .unavailable)
        XCTAssertNil(none.latestVersion)
        XCTAssertEqual(none.releaseLabel, "0.9.0")
        XCTAssertEqual(none.installableAssets, [])
        XCTAssertFalse(none.hasInstallableAssets)
        XCTAssertNil(none.latestReleaseLabel)
        XCTAssertNil(none.latestReleaseLabelForPrompt)
        XCTAssertEqual(none.detail, "No published release found.")
    }

    func testWorkbenchSnapshotPreservesBuildAwareSemantics() throws {
        let data = Data("""
        [
          {
            "tag_name": "v0.1.155",
            "html_url": "https://github.com/ourostack/ouro-workbench/releases/tag/v0.1.155",
            "draft": false,
            "prerelease": true,
            "assets": [
              {"name": "OuroWorkbench-0.1.154-build.999-deadbee.zip", "browser_download_url": "https://example.test/old.zip", "size": 100},
              {"name": "OuroWorkbench-0.1.155-build.340-cdf1190.zip", "browser_download_url": "https://example.test/app.zip", "size": 100},
              {"name": "OuroWorkbench-0.1.155-build.340-cdf1190.manifest.json", "browser_download_url": "https://example.test/manifest.json", "size": 50}
            ]
          }
        ]
        """.utf8)
        let configuration = ReleaseUpdateConfiguration(
            identity: workbenchIdentity,
            releasePolicy: .buildMatchedPrerelease(namePrefix: "OuroWorkbench-")
        )

        XCTAssertTrue(configuration.includePrereleases)
        let snapshot = try ReleaseUpdateChecker.snapshot(from: data, configuration: configuration)

        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.latestVersion, "0.1.155")
        XCTAssertEqual(snapshot.latestBuild, "340")
        XCTAssertEqual(snapshot.detail, "Version 0.1.155 (build 340) is available.")
        XCTAssertEqual(snapshot.currentReleaseLabel, "Version 0.1.155 (build 238)")
        XCTAssertEqual(snapshot.currentReleaseLabelForPrompt, "0.1.155 (build 238)")
        XCTAssertEqual(snapshot.latestReleaseLabel, "Version 0.1.155 (build 340)")
        XCTAssertEqual(snapshot.latestReleaseLabelForPrompt, "0.1.155 (build 340)")
        XCTAssertTrue(snapshot.hasInstallableAssets)
        XCTAssertEqual(snapshot.installableAssets.map(\.name), [
            "OuroWorkbench-0.1.155-build.340-cdf1190.zip",
            "OuroWorkbench-0.1.155-build.340-cdf1190.manifest.json"
        ])
    }

    func testWorkbenchSnapshotSelectsBestBuildAwareReleaseInsteadOfAPIOrder() throws {
        let data = Data("""
        [
          {
            "tag_name": "v0.1.155",
            "html_url": "https://github.com/ourostack/ouro-workbench/releases/tag/v0.1.155-build-239",
            "draft": false,
            "prerelease": true,
            "assets": [
              {"name": "OuroWorkbench-0.1.155-build.239-deadbee.zip", "browser_download_url": "https://example.test/old.zip", "size": 100},
              {"name": "OuroWorkbench-0.1.155-build.239-deadbee.manifest.json", "browser_download_url": "https://example.test/old.manifest.json", "size": 50}
            ]
          },
          {
            "tag_name": "v0.1.155",
            "html_url": "https://github.com/ourostack/ouro-workbench/releases/tag/v0.1.155",
            "draft": false,
            "prerelease": true,
            "assets": [
              {"name": "OuroWorkbench-0.1.155-build.340-cdf1190.zip", "browser_download_url": "https://example.test/app.zip", "size": 100},
              {"name": "OuroWorkbench-0.1.155-build.340-cdf1190.manifest.json", "browser_download_url": "https://example.test/manifest.json", "size": 50}
            ]
          }
        ]
        """.utf8)
        let configuration = ReleaseUpdateConfiguration(
            identity: AppShellIdentity(
                appName: "Ouro Workbench",
                bundleIdentifier: "com.ourostack.workbench",
                repository: "ourostack/ouro-workbench",
                version: "0.1.155",
                build: "300",
                userAgent: "OuroWorkbench/0.1.155"
            ),
            releasePolicy: .buildMatchedPrerelease(namePrefix: "OuroWorkbench-")
        )

        let snapshot = try ReleaseUpdateChecker.snapshot(from: data, configuration: configuration)

        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.latestVersion, "0.1.155")
        XCTAssertEqual(snapshot.latestBuild, "340")
        XCTAssertEqual(snapshot.tagName, "v0.1.155")
        XCTAssertEqual(snapshot.installableAssets.map(\.name), [
            "OuroWorkbench-0.1.155-build.340-cdf1190.zip",
            "OuroWorkbench-0.1.155-build.340-cdf1190.manifest.json"
        ])
    }

    func testCheckReturnsSnapshotAndUnavailableOnLoaderFailure() async {
        let success = ReleaseUpdateChecker(
            configuration: ReleaseUpdateConfiguration(identity: mdIdentity),
            dataLoader: { request in
                XCTAssertEqual(request.url?.absoluteString, "https://api.github.com/repos/ourostack/ouro-md/releases?per_page=10")
                return Data("""
                [{"tag_name":"v0.10.0","html_url":"https://example.test","draft":false,"prerelease":false,"assets":[]}]
                """.utf8)
            }
        )
        let successSnapshot = await success.check()
        XCTAssertEqual(successSnapshot.status, .updateAvailable)

        let failure = ReleaseUpdateChecker(
            configuration: ReleaseUpdateConfiguration(identity: mdIdentity),
            dataLoader: { _ in throw ReleaseUpdateError.badResponse }
        )
        let failureSnapshot = await failure.check()
        XCTAssertEqual(failureSnapshot.status, .unavailable)
        XCTAssertEqual(failureSnapshot.currentVersion, "0.9.22")
        XCTAssertTrue(failureSnapshot.detail.contains("Release update check failed"))
    }

    func testDefaultDataLoaderReturnsBodyAndThrowsOnBadResponses() async throws {
        let expectedData = Data("""
        [{"tag_name":"v0.9.22","html_url":"https://example.test","draft":false,"prerelease":false,"assets":[]}]
        """.utf8)
        RecordingURLProtocol.stub(response: .http(statusCode: 200), data: expectedData)
        let defaultLoaderSnapshot = await ReleaseUpdateChecker(
            configuration: ReleaseUpdateConfiguration(identity: mdIdentity)
        ).check()
        XCTAssertEqual(defaultLoaderSnapshot.status, .current)
        XCTAssertEqual(defaultLoaderSnapshot.latestVersion, "0.9.22")

        RecordingURLProtocol.stub(response: .http(statusCode: 200), data: expectedData)
        let success = try await ReleaseUpdateChecker.defaultDataLoader(
            request: ReleaseUpdateChecker.request(for: ReleaseUpdateConfiguration(identity: mdIdentity))
        )
        XCTAssertEqual(success, expectedData)
        let request = try XCTUnwrap(RecordingURLProtocol.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "OuroMD/0.9.22")

        RecordingURLProtocol.stub(response: .http(statusCode: 503), data: Data("unavailable".utf8))
        do {
            _ = try await ReleaseUpdateChecker.defaultDataLoader(
                request: URLRequest(url: URL(string: "https://api.github.com/repos/ourostack/ouro-md/releases")!)
            )
            XCTFail("Expected badResponse for non-2xx status.")
        } catch {
            XCTAssertEqual(error as? ReleaseUpdateError, .badResponse)
        }

        RecordingURLProtocol.stub(response: .plain, data: Data("plain".utf8))
        do {
            _ = try await ReleaseUpdateChecker.defaultDataLoader(
                request: URLRequest(url: URL(string: "https://api.github.com/repos/ourostack/ouro-md/releases")!)
            )
            XCTFail("Expected badResponse for non-HTTP response.")
        } catch {
            XCTAssertEqual(error as? ReleaseUpdateError, .badResponse)
        }
    }

    func testMalformedReleaseJSONThrows() {
        XCTAssertThrowsError(try ReleaseUpdateChecker.snapshot(from: Data("{\"not\":\"an array\"}".utf8), currentVersion: "0.9.0"))
    }
}

private final class RecordingURLProtocol: URLProtocol {
    enum StubResponse {
        case http(statusCode: Int)
        case plain
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubResponse: StubResponse = .http(statusCode: 200)
    nonisolated(unsafe) private static var stubData = Data()
    nonisolated(unsafe) private static var storedLastRequest: URLRequest?

    static var lastRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return storedLastRequest
    }

    static func stub(response: StubResponse, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        stubResponse = response
        stubData = data
        storedLastRequest = nil
    }

    static func reset() {
        stub(response: .http(statusCode: 200), data: Data())
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.github.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.storedLastRequest = request
        let response = Self.stubResponse
        let data = Self.stubData
        Self.lock.unlock()

        let url = request.url!
        let urlResponse: URLResponse
        switch response {
        case let .http(statusCode):
            urlResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        case .plain:
            urlResponse = URLResponse(url: url, mimeType: nil, expectedContentLength: data.count, textEncodingName: nil)
        }
        client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
