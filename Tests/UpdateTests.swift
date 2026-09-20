import Foundation

struct UpdateTests {
    static let fixture = """
    {
      "tag_name": "v0.4.0",
      "name": "GiGi 0.4.0",
      "html_url": "https://github.com/Zovaris/GiGi/releases/tag/v0.4.0",
      "draft": false,
      "prerelease": false,
      "published_at": "2026-09-21T10:00:00Z",
      "assets": [
        { "name": "GiGi-0.4.0-macos-arm64.zip",
          "browser_download_url": "https://example.com/GiGi.zip", "size": 1234 },
        { "name": "GiGi-0.4.0-macos-arm64.zip.sha256", "size": 90 }
      ]
    }
    """

    static func run() {
        assert(UpdateVersion.normalize("v0.4.0") == "0.4.0", "a leading v is decoration")
        assert(UpdateVersion.normalize("1.2") == "1.2.0", "a short version pads to three numbers")
        assert(UpdateVersion.normalize("0.4.0") == "0.4.0", "a plain version survives")
        assert(UpdateVersion.normalize("nightly") == nil, "a tag that is not a version is rejected")
        assert(UpdateVersion.normalize("0.4.0-beta.1") == nil, "a prerelease tag is not a version")
        assert(UpdateVersion.normalize("1.2.3.4") == nil, "four numbers are not a version")

        assert(UpdateVersion.isNewer("0.4.0", than: "0.3.0"), "0.4.0 is newer than 0.3.0")
        assert(UpdateVersion.isNewer("0.3.10", than: "0.3.9"), "numbers compare as numbers, not as text")
        assert(UpdateVersion.isNewer("0.10.0", than: "0.9.9"), "minor bumps win over patch bumps")
        assert(UpdateVersion.isNewer("1.0.0", than: "0.99.99"), "major bumps win")
        assert(UpdateVersion.isNewer("0.4", than: "0.3.9"), "a short candidate still compares")
        assert(!UpdateVersion.isNewer("0.3.0", than: "0.3.0"), "the same version is not newer")
        assert(!UpdateVersion.isNewer("0.2.9", than: "0.3.0"), "an older version is not newer")
        assert(!UpdateVersion.isNewer("nightly", than: "0.3.0"), "a candidate that is not a version is ignored")

        let data = Data(fixture.utf8)
        let release = UpdatePayload.release(from: data)
        assert(release?.version == "0.4.0", "the tag becomes the release version")
        assert(release?.tag == "v0.4.0", "the raw tag is kept")
        assert(release?.pageURL == "https://github.com/Zovaris/GiGi/releases/tag/v0.4.0", "the page comes from html_url")
        assert(release?.assets.count == 1, "only the assets with a download url are kept")
        assert(release?.assets.first?.url == "https://example.com/GiGi.zip", "the asset url survives")
        assert(release?.assets.first?.size == 1234, "the asset size survives")
        assert(release?.publishedAt == "2026-09-21T10:00:00Z", "the publish date survives")

        assert(UpdatePayload.release(from: Data("not json".utf8)) == nil, "garbage is not a release")
        assert(UpdatePayload.release(from: Data("{}".utf8)) == nil, "a payload without a tag is not a release")
        assert(UpdatePayload.release(from: Data(#"{"tag_name": "v0.4.0", "prerelease": true}"#.utf8)) == nil,
               "a prerelease is never offered as an update")
        assert(UpdatePayload.release(from: Data(#"{"tag_name": "v0.4.0", "draft": true}"#.utf8)) == nil,
               "a draft is never offered as an update")
        assert(UpdatePayload.release(from: Data(#"{"tag_name": "nightly"}"#.utf8)) == nil,
               "a tag that is not a version is not a release")

        let shorthand = UpdatePayload.release(from: Data(#"{"tag_name": "v0.4.0"}"#.utf8))
        assert(shorthand?.pageURL.hasSuffix("/releases/tag/v0.4.0") == true,
               "without html_url the tag page is built from the repository")
        assert(shorthand?.name == "v0.4.0", "without a name the tag is used")

        let url = UpdateFeed.latestRelease
        let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        let missing = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)
        let throttled = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)
        let broken = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)

        assert(UpdateChecker.evaluate(current: "0.3.0", data: data, response: ok, error: nil)
            == .available(release!), "a newer release is reported as available")
        assert(UpdateChecker.evaluate(current: "0.4.0", data: data, response: ok, error: nil) == .upToDate(current: "0.4.0"),
               "the same version is up to date")
        assert(UpdateChecker.evaluate(current: "0.5.0", data: data, response: ok, error: nil) == .upToDate(current: "0.5.0"),
               "a build ahead of the release is up to date")
        assert(UpdateChecker.evaluate(current: "0.3.0", data: nil, response: missing, error: nil) == .upToDate(current: "0.3.0"),
               "no published release is not an error")
        assert(UpdateChecker.evaluate(current: "0.3.0", data: nil, response: throttled, error: nil)
            == .failed("GitHub rate limit, try again later"), "a rate limit is reported")
        assert(UpdateChecker.evaluate(current: "0.3.0", data: nil, response: broken, error: nil)
            == .failed("GitHub answered 500"), "an unexpected status is reported")
        assert(UpdateChecker.evaluate(current: "0.3.0", data: Data("not json".utf8), response: ok, error: nil)
            == .failed("cannot read the release GitHub returned"), "unreadable data is reported")
        assert(UpdateChecker.evaluate(current: "0.3.0", data: nil, response: nil, error: nil)
            == .failed("no response from GitHub"), "a reply without a response is reported")
        if case .failed = UpdateChecker.evaluate(current: "0.3.0", data: nil, response: nil,
                                                 error: URLError(.notConnectedToInternet)) {
        } else {
            assertionFailure("a transport error must be reported")
        }
        if case .failed = UpdateChecker.evaluate(current: "nightly", data: data, response: ok, error: nil) {
        } else {
            assertionFailure("a current version that cannot be parsed must be reported")
        }

        var requested: URLRequest?
        let checker = UpdateChecker()
        checker.fetch = { request, completion in
            requested = request
            completion(data, ok, nil)
        }
        var outcome: UpdateCheck?
        checker.check(current: "0.3.0") { outcome = $0 }
        assert(requested?.url == UpdateFeed.latestRelease, "the checker asks the releases endpoint")
        assert(requested?.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json",
               "the checker asks for the stable API")
        assert(requested?.value(forHTTPHeaderField: "User-Agent") == "GiGi/0.3.0",
               "the checker identifies the build that is asking")

        let deadline = Date().addingTimeInterval(2)
        while outcome == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        assert(outcome == .available(release!), "the answer arrives on the main queue")

        assert(Config.default.checkForUpdates, "update checks are on by default")
        let legacy = Data(#"{"intervalSeconds": [45, 90], "idleThresholdSeconds": 40}"#.utf8)
        if let config = try? JSONDecoder().decode(Config.self, from: legacy) {
            assert(config.checkForUpdates, "a configuration without the key keeps checking")
        } else {
            assertionFailure("a configuration without the key must still decode")
        }

        print("Update version, payload and check checks passed")
    }
}
