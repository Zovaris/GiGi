import Foundation

struct UpdateAsset: Equatable {
    var name: String
    var url: String
    var size: Int
}

struct UpdateRelease: Equatable {
    var version: String
    var tag: String
    var name: String
    var pageURL: String
    var publishedAt: String?
    var assets: [UpdateAsset]
}

enum UpdateCheck: Equatable {
    case upToDate(current: String)
    case available(UpdateRelease)
    case failed(String)
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available(String)
    case failed(String)
}

enum UpdateFeed {
    static let repository = "Zovaris/GiGi"
    static let latestRelease = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
}

enum UpdateVersion {
    static func parts(_ text: String) -> [Int]? {
        var value = text.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("v") || value.hasPrefix("V") { value.removeFirst() }
        guard !value.isEmpty else { return nil }
        let fields = value.split(separator: ".", omittingEmptySubsequences: false)
        guard fields.count <= 3 else { return nil }
        var numbers: [Int] = []
        for field in fields {
            guard !field.isEmpty, field.allSatisfy(\.isNumber), let number = Int(field) else { return nil }
            numbers.append(number)
        }
        while numbers.count < 3 { numbers.append(0) }
        return numbers
    }

    static func normalize(_ text: String) -> String? {
        guard let numbers = parts(text) else { return nil }
        return numbers.map(String.init).joined(separator: ".")
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let left = parts(candidate), let right = parts(current) else { return false }
        for index in 0..<3 where left[index] != right[index] {
            return left[index] > right[index]
        }
        return false
    }
}

enum UpdatePayload {
    static func release(from data: Data) -> UpdateRelease? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        if payload.draft == true || payload.prerelease == true { return nil }
        guard let version = UpdateVersion.normalize(payload.tagName) else { return nil }
        let assets = (payload.assets ?? []).compactMap { asset -> UpdateAsset? in
            guard let url = asset.browserDownloadURL else { return nil }
            return UpdateAsset(name: asset.name, url: url, size: asset.size ?? 0)
        }
        return UpdateRelease(
            version: version,
            tag: payload.tagName,
            name: payload.name ?? payload.tagName,
            pageURL: payload.htmlURL ?? "https://github.com/\(UpdateFeed.repository)/releases/tag/\(payload.tagName)",
            publishedAt: payload.publishedAt,
            assets: assets
        )
    }

    private struct Payload: Decodable {
        var tagName: String
        var name: String?
        var htmlURL: String?
        var draft: Bool?
        var prerelease: Bool?
        var publishedAt: String?
        var assets: [Asset]?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
            case draft
            case prerelease
            case publishedAt = "published_at"
            case assets
        }

        struct Asset: Decodable {
            var name: String
            var browserDownloadURL: String?
            var size: Int?

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
                case size
            }
        }
    }
}

final class UpdateChecker {
    typealias Fetch = (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void

    var fetch: Fetch = { request, completion in
        URLSession.shared.dataTask(with: request, completionHandler: completion).resume()
    }
    var timeout: TimeInterval = 10

    func check(current: String, completion: @escaping (UpdateCheck) -> Void) {
        guard UpdateVersion.parts(current) != nil else {
            DispatchQueue.main.async { completion(.failed("unknown current version")) }
            return
        }
        var request = URLRequest(url: UpdateFeed.latestRelease, timeoutInterval: timeout)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GiGi/\(current)", forHTTPHeaderField: "User-Agent")
        fetch(request) { data, response, error in
            let outcome = UpdateChecker.evaluate(current: current, data: data, response: response, error: error)
            DispatchQueue.main.async { completion(outcome) }
        }
    }

    static func evaluate(current: String, data: Data?, response: URLResponse?, error: Error?) -> UpdateCheck {
        guard UpdateVersion.parts(current) != nil else { return .failed("unknown current version") }
        if let error { return .failed(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse else { return .failed("no response from GitHub") }
        switch http.statusCode {
        case 200:
            guard let data, let release = UpdatePayload.release(from: data) else {
                return .failed("cannot read the release GitHub returned")
            }
            return UpdateVersion.isNewer(release.version, than: current) ? .available(release) : .upToDate(current: current)
        case 404:
            return .upToDate(current: current)
        case 403, 429:
            return .failed("GitHub rate limit, try again later")
        default:
            return .failed("GitHub answered \(http.statusCode)")
        }
    }
}
